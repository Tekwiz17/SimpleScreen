# Make an HTML widget

Add HTML under Widgets, choose Customize, and paste a self-contained snippet or import an HTML file under 1 MB. CSS and JavaScript are supported.

```html
<style>
  body { margin:0; height:100vh; display:grid; place-items:center; color:white; font:22px system-ui; }
  button { border:1px solid #ffffff44; border-radius:18px; padding:18px; color:inherit; background:#ffffff15; cursor:pointer; }
</style>
<button id="breathe">Take a breath</button>
<script>
  const button = document.querySelector('#breathe');
  button.onclick = () => {
    button.textContent = 'In… and out.';
    button.animate([{transform:'scale(1)'},{transform:'scale(1.1)'},{transform:'scale(1)'}], {duration:4000, easing:'ease-in-out'});
    setTimeout(() => button.textContent = 'Take a breath', 4000);
  };
</script>
```

Enable interactions to click it; leave Arrange mode first. Choose a clear surface if your HTML supplies its own card, or glass for native backdrop blur.

## Boundaries

- Inline scripts and styles are allowed.
- HTTPS resources/requests are disabled unless you explicitly enable them for that widget.
- Data-URL images/fonts and inline SVG work offline.
- File URLs, iframes, plug-ins, forms, navigation, pop-ups, and native commands are unavailable.
- There is no native script bridge. HTML cannot access SimpleScreen's preferences, battery, AI sessions, or weather data through the app.
- Storage is ephemeral; do not rely on localStorage surviving app relaunch.
- External links do not open. Use buttons for in-widget interactions.
- All author content follows an app-supplied Content Security Policy placed before it.
- Only enable HTTPS access for code you trust: remote scripts can read and transmit content inside that widget.
- Custom JavaScript can still consume CPU. Respect `prefers-reduced-motion`, avoid perpetual high-frequency timers, and remove widgets that behave poorly.

HTML widgets are portable WebKit snippets, not a privileged desktop extension runtime.
