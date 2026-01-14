const TOOLS = TOOL_SCHEMAS_PLACEHOLDER;
const CATEGORIES = CATEGORIES_PLACEHOLDER;

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
  const select = document.getElementById('tool-select');
  TOOLS.forEach(tool => {
    const option = document.createElement('option');
    option.value = tool.name;
    option.textContent = tool.name;
    select.appendChild(option);
  });
  renderToolForm();
});

function renderToolForm() {
  const toolName = document.getElementById('tool-select').value;
  const tool = TOOLS.find(t => t.name === toolName);
  if (!tool) return;

  const schema = tool.inputSchema || {};
  const properties = schema.properties || {};
  const required = schema.required || [];
  const formContainer = document.getElementById('tool-form');

  let html = '';
  for (const [propName, propDef] of Object.entries(properties)) {
    const isRequired = required.includes(propName);
    const requiredMark = isRequired ? '<span class="required">*</span>' : '';
    const description = propDef.description || '';

    html += '<div class="form-group">';
    html += '<label class="form-label" for="field-' + propName + '">' + propName + ' ' + requiredMark + '</label>';

    if (propDef.enum) {
      // Render as select for enum types
      html += '<select id="field-' + propName + '" class="form-select" data-type="' + propDef.type + '"' + (isRequired ? ' required' : '') + '>';
      html += '<option value="">-- Select --</option>';
      propDef.enum.forEach(val => {
        html += '<option value="' + val + '">' + val + '</option>';
      });
      html += '</select>';
    } else if (propDef.type === 'integer') {
      let attrs = '';
      if (propName === 'limit') {
        attrs = ' min="1" max="20" value="20"';
      }
      html += '<input type="number" id="field-' + propName + '" class="form-input" data-type="integer" placeholder="' + description.replace(/"/g, '&quot;') + '"' + attrs + (isRequired ? ' required' : '') + '>';
    } else if (propName === 'category') {
      // Render category as a dropdown with prepopulated list
      html += '<select id="field-' + propName + '" class="form-select" data-type="string"' + (isRequired ? ' required' : '') + '>';
      html += '<option value="">-- All Categories --</option>';
      CATEGORIES.forEach(cat => {
        html += '<option value="' + cat + '">' + cat + '</option>';
      });
      html += '</select>';
    } else {
      html += '<input type="text" id="field-' + propName + '" class="form-input" data-type="string" placeholder="' + description.replace(/"/g, '&quot;') + '"' + (isRequired ? ' required' : '') + '>';
    }

    if (description) {
      html += '<div class="form-hint">' + description + '</div>';
    }
    html += '</div>';
  }

  formContainer.innerHTML = html;
  document.getElementById('tool-result').className = 'result-area';
  document.getElementById('tool-result').textContent = '';
}

function collectFormArguments() {
  const args = {};
  const inputs = document.querySelectorAll('#tool-form input, #tool-form select');

  inputs.forEach(input => {
    const name = input.id.replace('field-', '');
    const value = input.value.trim();
    const type = input.dataset.type;

    if (value === '') return; // Skip empty optional fields

    if (type === 'integer') {
      args[name] = parseInt(value, 10);
    } else {
      args[name] = value;
    }
  });

  return args;
}

function handleSubmit(event) {
  event.preventDefault();
  executeTool();
  return false;
}

function convertListsToDefinitionLists(container) {
  // Convert <ul> lists that contain definition-like items to <dl>
  // Pattern: <li><strong>name</strong> <code>(type)</code> — description</li>
  const lists = container.querySelectorAll('ul');
  lists.forEach(ul => {
    const items = ul.querySelectorAll('li');
    // Check if items match the definition pattern (contain em dash separator)
    const isDefinitionList = Array.from(items).every(li => li.innerHTML.includes(' — '));
    if (!isDefinitionList || items.length === 0) return;

    const dl = document.createElement('dl');
    items.forEach(li => {
      const parts = li.innerHTML.split(' — ');
      if (parts.length >= 2) {
        const dt = document.createElement('dt');
        dt.innerHTML = parts[0];
        const dd = document.createElement('dd');
        dd.innerHTML = parts.slice(1).join(' — '); // Handle case where description contains em dash
        dl.appendChild(dt);
        dl.appendChild(dd);
      }
    });
    ul.replaceWith(dl);
  });
}

async function executeTool() {
  const toolName = document.getElementById('tool-select').value;
  const args = collectFormArguments();
  const resultArea = document.getElementById('tool-result');
  const executeBtn = document.getElementById('execute-btn');

  // Show loading state
  resultArea.className = 'result-area visible';
  resultArea.innerHTML = '<span class="loading">Executing...</span>';
  executeBtn.disabled = true;

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
      resultArea.className = 'result-area visible error';
      resultArea.textContent = 'Error: ' + (data.error.message || JSON.stringify(data.error));
    } else if (data.result && data.result.content) {
      const content = data.result.content[0];
      const isError = data.result.isError;
      resultArea.className = 'result-area visible' + (isError ? ' error' : ' success');
      const text = content.text || JSON.stringify(content);
      resultArea.innerHTML = marked.parse(text);
      convertListsToDefinitionLists(resultArea);
    } else {
      resultArea.className = 'result-area visible';
      resultArea.textContent = JSON.stringify(data, null, 2);
    }
  } catch (err) {
    resultArea.className = 'result-area visible error';
    resultArea.textContent = 'Network error: ' + err.message;
  } finally {
    executeBtn.disabled = false;
  }
}
