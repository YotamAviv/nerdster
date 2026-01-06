const http = require('http');
const { executeFetchImages } = require('./core_logic');

const PORT = 3000;

const HTML = `
<!DOCTYPE html>
<html>
<head>
  <title>Metadata Debugger</title>
  <style>
    body { font-family: sans-serif; padding: 20px; }
    textarea { width: 100%; height: 100px; margin-bottom: 10px; font-family: monospace; }
    .images { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 20px; }
    .img-card { border: 1px solid #ccc; padding: 5px; max-width: 200px; }
    .img-card img { max-width: 100%; height: auto; display: block; }
    .img-card p { font-size: 12px; word-break: break-all; margin: 5px 0 0; }
    .error { color: red; background: #ffe6e6; padding: 10px; display: none; }
  </style>
</head>
<body>
  <h1>Metadata Debugger</h1>
  <p>Enter a URL or a JSON object representing a subject.</p>
  
  <textarea id="input" placeholder='{"url": "...", "title": "..."} or https://...'></textarea>
  <br>
  <button onclick="fetchImages()">Fetch Images</button>
  <div id="error" class="error"></div>
  <div id="results"></div>

  <script>
    async function fetchImages() {
      const input = document.getElementById('input').value;
      const errorDiv = document.getElementById('error');
      const resultsDiv = document.getElementById('results');
      
      errorDiv.style.display = 'none';
      resultsDiv.innerHTML = 'Loading...';

      let subject = {};
      
      try {
        if (input.trim().startsWith('http')) {
          subject = { url: input.trim() };
        } else {
          subject = JSON.parse(input);
        }
      } catch (e) {
        errorDiv.textContent = 'Invalid JSON input';
        errorDiv.style.display = 'block';
        resultsDiv.innerHTML = '';
        return;
      }

      try {
        const response = await fetch('/api/fetch', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(subject)
        });
        
        const data = await response.json();
        
        if (!response.ok) {
          throw new Error(data.error || 'Server error');
        }
        
        let html = \`<h2>Title: \${data.title || 'N/A'}</h2>\`;
        html += '<div class=\"images\">';
        
        if (data.images && data.images.length > 0) {
          data.images.forEach(img => {
            const proxyUrl = 'https://wsrv.nl/?url=' + encodeURIComponent(img) + '&w=200&h=200&fit=cover';
            html += \`
              <div class="img-card">
                <div style="margin-bottom: 10px;">
                  <strong style="display:block; margin-bottom:4px;">Direct</strong>
                  <img src="\${img}" />
                  <p><a href="\${img}" target="_blank">Open Direct</a></p>
                </div>
                <div style="border-top: 1px dashed #ccc; padding-top: 10px;">
                  <strong style="display:block; margin-bottom:4px;">Proxy (wsrv.nl)</strong>
                  <img src="\${proxyUrl}" onerror="this.style.display='none'; this.nextElementSibling.innerText='Proxy Failed (404/Block)';" />
                  <p style="color:red; display:none"></p>
                  <p><a href="\${proxyUrl}" target="_blank">Open Proxy</a></p>
                </div>
              </div>
            \`;
          });
        } else {
          html += '<p>No images found.</p>';
        }
        html += '</div>';
        resultsDiv.innerHTML = html;

      } catch (e) {
        errorDiv.textContent = e.message;
        errorDiv.style.display = 'block';
        resultsDiv.innerHTML = '';
      }
    }
  </script>
</body>
</html>
`;

const server = http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(HTML);
    return;
  }

  if (req.method === 'POST' && req.url === '/api/fetch') {
    let body = '';
    req.on('data', chunk => { body += chunk; });
    req.on('end', async () => {
      try {
        const subject = JSON.parse(body);
        const logger = {
          info: (...args) => console.log('[INFO]', ...args),
          error: (...args) => console.error('[ERROR]', ...args),
        };
        
        const result = await executeFetchImages(subject, logger);
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result));
      } catch (e) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  res.writeHead(404);
  res.end('Not Found');
});

server.listen(PORT, () => {
  console.log(`Debug server running at http://localhost:${PORT}`);
});
