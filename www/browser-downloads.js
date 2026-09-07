// Chromium downloads can bypass Shinylive's virtual service-worker routes.
// Fetch within the app first, then download a browser-local Blob instead.
document.addEventListener('click', async (event) => {
  const link = event.target.closest('a.shiny-download-link');
  if (!link || link.classList.contains('disabled') || !link.getAttribute('href')) return;
  event.preventDefault();
  event.stopImmediatePropagation();
  document.getElementById('browser-download-error')?.remove();
  try {
    const response = await fetch(link.href);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const disposition = response.headers.get('Content-Disposition') || '';
    const filename = disposition.match(/filename="([^"]+)"/i)?.[1];
    if (!filename) throw new Error('The response did not include a download filename.');
    const url = URL.createObjectURL(await response.blob());
    const download = document.createElement('a');
    download.href = url;
    download.download = filename;
    document.body.append(download);
    download.click();
    download.remove();
    setTimeout(() => URL.revokeObjectURL(url), 60_000);
  } catch (error) {
    const notice = document.createElement('p');
    notice.id = 'browser-download-error';
    notice.className = 'notice';
    notice.setAttribute('role', 'alert');
    notice.textContent = 'Download could not be completed. Check the current inputs and try again.';
    link.after(notice);
  }
}, true);
