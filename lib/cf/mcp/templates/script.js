import { h, render } from 'https://esm.sh/preact@10';
import { useState, useEffect, useRef, useCallback } from 'https://esm.sh/preact@10/hooks';
import htm from 'https://esm.sh/htm@3';

const html = htm.bind(h);

const TOOLS = TOOL_SCHEMAS_PLACEHOLDER;
const CATEGORIES = CATEGORIES_PLACEHOLDER;
const TOPICS = TOPICS_PLACEHOLDER;

// Helper to render topic options (used in multiple places)
const renderTopicOptions = () =>
  TOPICS.map(topic => html`<option value=${topic.name}>${topic.name.replace(/_/g, ' ')}</option>`);

// Reusable select field component
function SelectField({ id, label, value, onChange, required, placeholder, options }) {
  return html`
    <div class="form-group">
      <label class="form-label" for=${id}>${label}</label>
      <select id=${id} class="form-select" value=${value} onChange=${onChange} required=${required}>
        <option value="">${placeholder}</option>
        ${options}
      </select>
    </div>
  `;
}

// Custom hook for MCP tool calls
function useMcpToolCall() {
  const [result, setResult] = useState({ loading: false, error: null, content: null });

  const callTool = useCallback(async (toolName, args = {}, loadingText = 'Loading...') => {
    setResult({ loading: true, loadingText, error: null, content: null });

    try {
      const response = await fetch('/http', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/event-stream'
        },
        body: JSON.stringify({
          jsonrpc: '2.0',
          id: Date.now(),
          method: 'tools/call',
          params: { name: toolName, arguments: args }
        })
      });

      const data = await response.json();

      if (data.error) {
        setResult({ loading: false, error: 'Error: ' + (data.error.message || JSON.stringify(data.error)), content: null });
      } else if (data.result?.content) {
        const content = data.result.content[0];
        const text = content.text || JSON.stringify(content);
        setResult({
          loading: false,
          error: data.result.isError ? text : null,
          content: data.result.isError ? null : text
        });
      } else {
        setResult({ loading: false, error: null, content: JSON.stringify(data, null, 2) });
      }
    } catch (err) {
      setResult({ loading: false, error: 'Network error: ' + err.message, content: null });
    }
  }, []);

  const reset = useCallback(() => {
    setResult({ loading: false, error: null, content: null });
  }, []);

  return { result, callTool, reset };
}

// Shared ResultArea component
function ResultArea({ result }) {
  const containerRef = useRef(null);

  useEffect(() => {
    if (result.content && containerRef.current) {
      containerRef.current.innerHTML = marked.parse(result.content);
      convertListsToDefinitionLists(containerRef.current);
    }
  }, [result.content]);

  if (result.loading) {
    return html`<div class="result-area visible"><span class="loading">${result.loadingText || 'Loading...'}</span></div>`;
  }

  if (result.error) {
    return html`<div class="result-area visible error">${result.error}</div>`;
  }

  if (result.content) {
    return html`<div class="result-area visible success" ref=${containerRef}></div>`;
  }

  return html`<div class="result-area"></div>`;
}

function convertListsToDefinitionLists(container) {
  const lists = container.querySelectorAll('ul');
  lists.forEach(ul => {
    const items = ul.querySelectorAll('li');
    const isDefinitionList = Array.from(items).every(li => li.innerHTML.includes(' — '));
    if (!isDefinitionList || items.length === 0) return;

    const dl = document.createElement('dl');
    items.forEach(li => {
      const parts = li.innerHTML.split(' — ');
      if (parts.length >= 2) {
        const dt = document.createElement('dt');
        dt.innerHTML = parts[0];
        const dd = document.createElement('dd');
        dd.innerHTML = parts.slice(1).join(' — ');
        dl.appendChild(dt);
        dl.appendChild(dd);
      }
    });
    ul.replaceWith(dl);
  });
}

// Helper to create a select input
function renderSelect(id, value, onChange, required, placeholder, options) {
  return html`
    <select id=${id} class="form-select" value=${value} onChange=${onChange} required=${required}>
      <option value="">${placeholder}</option>
      ${options}
    </select>
  `;
}

// Form field component
function FormField({ name, propDef, required, value, onChange, toolName }) {
  const id = `field-${name}`;
  const description = propDef.description || '';
  const handleChange = e => onChange(name, e.target.value);

  let input;

  if (propDef.enum) {
    input = renderSelect(id, value, handleChange, required, '-- Select --',
      propDef.enum.map(val => html`<option value=${val}>${val}</option>`));
  } else if (propDef.type === 'integer') {
    const attrs = name === 'limit' ? { min: 1, max: 20 } : {};
    input = html`
      <input
        type="number"
        id=${id}
        class="form-input"
        placeholder=${description}
        value=${value}
        onChange=${e => onChange(name, e.target.value ? parseInt(e.target.value, 10) : '')}
        required=${required}
        ...${attrs}
      />
    `;
  } else if (name === 'category') {
    input = renderSelect(id, value, handleChange, required, '-- All Categories --',
      CATEGORIES.map(cat => html`<option value=${cat}>${cat}</option>`));
  } else if (name === 'name' && toolName === 'cf_get_topic') {
    input = renderSelect(id, value, handleChange, required, '-- Select Topic --', renderTopicOptions());
  } else {
    input = html`
      <input
        type="text"
        id=${id}
        class="form-input"
        placeholder=${description}
        value=${value}
        onInput=${e => onChange(name, e.target.value)}
        required=${required}
      />
    `;
  }

  return html`
    <div class="form-group">
      <label class="form-label" for=${id}>
        ${name} ${required && html`<span class="required">*</span>`}
      </label>
      ${input}
      ${description && html`<div class="form-hint">${description}</div>`}
    </div>
  `;
}

// Tool Explorer component
function ToolExplorer() {
  const [selectedTool, setSelectedTool] = useState(TOOLS[0]?.name || '');
  const [formValues, setFormValues] = useState({ limit: 20 });
  const { result, callTool, reset } = useMcpToolCall();

  const tool = TOOLS.find(t => t.name === selectedTool);
  const schema = tool?.inputSchema || {};
  const properties = schema.properties || {};
  const required = schema.required || [];

  const handleFieldChange = (name, value) => {
    setFormValues(prev => ({ ...prev, [name]: value }));
  };

  const handleToolChange = (e) => {
    setSelectedTool(e.target.value);
    reset();
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    const args = {};
    for (const [name, value] of Object.entries(formValues)) {
      if (value !== '' && value !== undefined && properties[name]) {
        args[name] = value;
      }
    }

    callTool(selectedTool, args, 'Executing...');
  };

  return html`
    <div class="explorer">
      <form onSubmit=${handleSubmit}>
        <${SelectField}
          id="tool-select"
          label="Select Tool"
          value=${selectedTool}
          onChange=${handleToolChange}
          placeholder="-- Select Tool --"
          options=${TOOLS.map(t => html`<option value=${t.name}>${t.name}</option>`)}
        />
        ${Object.entries(properties).map(([propName, propDef]) => html`
          <${FormField}
            key=${propName}
            name=${propName}
            propDef=${propDef}
            required=${required.includes(propName)}
            value=${formValues[propName] ?? (propName === 'limit' ? 20 : '')}
            onChange=${handleFieldChange}
            toolName=${selectedTool}
          />
        `)}
        <button type="submit" class="btn-execute" disabled=${result.loading}>Execute</button>
      </form>
      <${ResultArea} result=${result} />
    </div>
  `;
}

// Topics Explorer component
function TopicsExplorer() {
  const [selectedTopic, setSelectedTopic] = useState('');
  const { result, callTool, reset } = useMcpToolCall();

  const handleChange = (e) => {
    const value = e.target.value;
    setSelectedTopic(value);
    if (value) {
      callTool('cf_get_topic', { name: value }, 'Loading topic...');
    } else {
      reset();
    }
  };

  return html`
    <div class="explorer">
      <${SelectField}
        id="topic-select"
        label="Select Topic"
        value=${selectedTopic}
        onChange=${handleChange}
        placeholder="-- Select a topic --"
        options=${renderTopicOptions()}
      />
      <${ResultArea} result=${result} />
    </div>
  `;
}

// Mount components
render(html`<${ToolExplorer} />`, document.getElementById('tool-explorer-root'));
render(html`<${TopicsExplorer} />`, document.getElementById('topics-explorer-root'));
