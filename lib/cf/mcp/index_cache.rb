# frozen_string_literal: true

require "digest"
require "fileutils"
require "tempfile"

module CF
  module MCP
    # Keeps the parsed index on disk so a command need not reparse every header.
    #
    # There is one cache file per source, so projects on different Cute Framework
    # versions do not evict each other. Each records where it was built from, so
    # a lookup needs no path resolution (or download) of its own, and rebuilds
    # when any header or topic file changes. The last source used is remembered
    # for commands that name none.
    class IndexCache
      FORMAT = 1
      DEFAULT_SOURCE = {root: nil, download: false} #: source

      Payload = Data.define(:format, :gem_version, :headers_path, :topics_path,
        :fingerprint, :revision, :items)

      def self.default_dir
        ENV["CF_MCP_CACHE_DIR"] || File.join(ENV["XDG_CACHE_HOME"] || File.expand_path("~/.cache"), "cf-mcp")
      end

      # The cache file used by the last #index or #refresh, and the checkout it came from.
      attr_reader :path, :revision

      def initialize(dir: self.class.default_dir)
        @dir = dir
      end

      def path_for(source)
        File.join(@dir, "index-#{Digest::SHA256.hexdigest("#{source[:root]}\n#{source[:download]}")[0, 12]}.bin")
      end

      # Loads the cached index if it is fresh, otherwise builds and stores it.
      # `source` names what to build from; nil means the last one used.
      # The block receives the source to build from and returns an IndexBuilder.
      def index(source = nil, &builder_for)
        source ||= current_source
        payload = load_payload(path_for(source))
        return hydrate(source, payload) if payload && fresh?(payload)

        warn "Index #{payload ? "is stale" : "not found"}, rebuilding..."
        rebuild(source, &builder_for)
      end

      # Rebuilds and stores the index, whether or not the cache is fresh.
      def refresh(source = nil, &builder_for)
        rebuild(source || current_source, &builder_for)
      end

      private

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
        write_atomically(path_for(source), Marshal.dump(Payload.new(
          format: FORMAT,
          gem_version: VERSION,
          headers_path: builder.headers_path,
          topics_path: builder.topics_path,
          fingerprint: fingerprint(builder.headers_path, builder.topics_path),
          revision: builder.revision,
          items: index.items.values
        )))
        use(source, builder.revision)
        index
      end

      def hydrate(source, payload)
        index = Index.instance
        index.reset!
        payload.items.each { |item| index.add(item) }
        use(source, payload.revision)
        index
      end

      def use(source, revision)
        @path = path_for(source)
        @revision = revision
        write_atomically(current_path, Marshal.dump(source)) unless current_source == source
      end

      def current_path
        File.join(@dir, "current")
      end

      def current_source
        Marshal.load(File.binread(current_path)) #: source
      rescue
        DEFAULT_SOURCE
      end

      def load_payload(path)
        payload = Marshal.load(File.binread(path)) #: Payload
        payload if payload.format == FORMAT && payload.gem_version == VERSION
      rescue
        nil
      end

      # Written beside the file and renamed into place, so a reader never sees half of it.
      def write_atomically(path, data)
        FileUtils.mkdir_p(File.dirname(path))
        Tempfile.create(["cf-mcp", ".tmp"], File.dirname(path), binmode: true) do |file|
          file.write(data)
          file.close
          File.rename(file.path, path)
        end
      end

      def fingerprint(headers_path, topics_path)
        files = Dir.glob(File.join(headers_path, "**/*.h"))
        files += Dir.glob(File.join(topics_path, "*.md")) if topics_path
        stats = files.sort.filter_map do |file|
          stat = File.stat(file)
          [file, stat.mtime.to_f, stat.size].join(":")
        rescue Errno::ENOENT
          # Gone since it was listed: a header being replaced, as during an update.
          nil
        end
        Digest::SHA256.hexdigest(stats.join("\n"))
      end
    end
  end
end
