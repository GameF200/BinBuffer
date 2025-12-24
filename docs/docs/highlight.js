
document.addEventListener('DOMContentLoaded', function() {
    if (!document.querySelector('.codehilite')) {
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/styles/github-dark.min.css';
        document.head.appendChild(link);
        
        const script = document.createElement('script');
        script.src = 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/highlight.min.js';
        script.onload = function() {
            const luaScript = document.createElement('script');
            luaScript.src = 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/languages/lua.min.js';
            luaScript.onload = function() {
                hljs.highlightAll();
                document.querySelectorAll('code.language-luau').forEach(el => {
                    el.className = 'language-lua';
                });
                hljs.highlightAll();
            };
            document.head.appendChild(luaScript);
        };
        document.head.appendChild(script);
    }
});