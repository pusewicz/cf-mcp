# frozen_string_literal: true

require "digest"
require "fileutils"
require "tempfile"

module CF
  module MCP
    # Keeps the parsed index on disk so a command need not reparse every header.
    #
    # The cache records where it was built from, so a lookup needs no path
    # resolution (or download) of its own, and rebuilds when any header or topic
    # file changes.
    class IndexCache
      FORMAT = 1
      DEFAULT_SOURCE = {root: nil, download: false} #: source

      Payload = Data.define(:format, :gem_version, :source, :headers_path, :topics_path,
        :fingerprint, :revision, :items)

      def self.default_dir
        ENV["CF_MCP_CACHE_DIR"] || File.join(ENV["XDG_CACHE_HOME"] || File.expand_path("~/.cache"), "cf-mcp")
      end

      attr_reader :path, :revision

      def initialize(dir: self.class.default_dir)
        @path = File.join(dir, "index.bin")
      end

      # Loads the cached index if it is fresh, otherwise builds and stores it.
      # `source` names what to build from; nil accepts whatever was cached.
      # The block receives the source to build from and returns an IndexBuilder.
      def index(source = nil, &builder_for)
        payload = load_payload
        return hydrate(payload) if payload && usable?(payload, source)

        warn "Index #{payload ? "is stale" : "not found"}, rebuilding..."
        rebuild(source || payload&.source || DEFAULT_SOURCE, &builder_for)
      end

      # Rebuilds and stores the index, whether or not the cache is fresh.
      def refresh(source = nil, &builder_for)
        rebuild(source || load_payload&.source || DEFAULT_SOURCE, &builder_for)
      end

      private

      def usable?(payload, source)
        (source.nil? || source == payload.source) && fresh?(payload)
      end

      # A checkout that has gone away (a cleaned download directory, say) keeps
      # its cache: only `refresh` should fetch it again.
      def fresh?(payload)
        !File.directory?(payload.headers_path) ||
          fingerprint(payload.headers_path, payload.topics_path) == payload.fingerprint
      end

      def rebuild(source)
        builder = yield source
        unless builder.valid?
          raise Error, "Headers directory not found: #{builder.headers_path}. Point --root at a Cute Framework checkout, or use --download."
        end

        index = builder.build
        store(Payload.new(
          format: FORMAT,
          gem_version: VERSION,
          source: source,
          headers_path: builder.headers_path,
          topics_path: builder.topics_path,
          fingerprint: fingerprint(builder.headers_path, builder.topics_path),
          revision: builder.revision,
          items: index.items.values
        ))
        @revision = builder.revision
        index
      end

      def hydrate(payload)
        index = Index.instance
        index.reset!
        payload.items.each { |item| index.add(item) }
        @revision = payload.revision
        index
      end

      def load_payload
        payload = Marshal.load(File.binread(path)) #: Payload
        payload if payload.format == FORMAT && payload.gem_version == VERSION
      rescue
        nil
      end

      # Written beside the cache and renamed into place, so a reader never sees half a file.
      def store(payload)
        FileUtils.mkdir_p(File.dirname(path))
        Tempfile.create(["index", ".tmp"], File.dirname(path), binmode: true) do |file|
          file.write(Marshal.dump(payload))
          file.close
          File.rename(file.path, path)
        end
      end

      def fingerprint(headers_path, topics_path)
        files = Dir.glob(File.join(headers_path, "**/*.h"))
        files += Dir.glob(File.join(topics_path, "*.md")) if topics_path
        stats = files.sort.map { |file| [file, File.mtime(file).to_f, File.size(file)].join(":") }
        Digest::SHA256.hexdigest(stats.join("\n"))
      end
    end
  end
end
