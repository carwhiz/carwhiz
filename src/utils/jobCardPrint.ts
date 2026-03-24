/**
 * Utility for printing job cards - matching desktop format exactly
 * Extracted to separate file to avoid template literal parser issues
 */

interface PrintJobCardData {
  jobCardNumber: string;
  createdByUser: string;
  customerName: string;
  vehicleInfo: string;
  totalAmount: number;
  items: Array<{
    item_type: string;
    name: string;
    qty: number;
    price: number;
    discount: number;
    total: number;
  }>;
  description: string;
  details: string;
  assignedToUser: string;
  priority: string;
  expectedDate: string;
  savedImages: Array<{ file_url: string; file_name?: string }>;
  logoBase64: string | null;
}

function escapeHtml(text: string): string {
  const map: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  };
  return text.replace(/[&<>"']/g, char => map[char]);
}

export function printJobCard(data: PrintJobCardData): void {
  const win = window.open('', 'job-card-print', 'height=900,width=900');
  if (!win) {
    alert('Please allow popups to print job cards');
    return;
  }

  // Build static CSS
  const styleContent = `
    * { margin: 0; padding: 0; box-sizing: border-box; }
    @page { size: A4; margin: 10mm; }
    @media print { body { margin: 0; padding: 0; } .page-break { page-break-after: always; } }
    body { font-family: Arial, sans-serif; font-size: 12px; line-height: 1.3; color: #333; background: white; width: 100%; margin: 0; padding: 15px; }
    .container { width: 100%; max-width: 800px; margin: 0 auto; background: white; }
    .logo-header { text-align: center; margin-bottom: 12px; border-bottom: 2px solid #333; padding-bottom: 8px; }
    .logo-header img { max-height: 60px; max-width: 150px; }
    h2 { margin: 6px 0; text-align: center; font-size: 16px; font-weight: bold; }
    .job-info { text-align: center; margin: 6px 0; font-size: 11px; font-weight: bold; word-break: break-all; }
    .cards-row { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin: 10px 0; width: 100%; }
    .inspection-row { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin: 10px 0; width: 100%; }
    .card { border: 1px solid #333; padding: 8px; background: #fafafa; width: 100%; overflow: hidden; word-wrap: break-word; }
    .card-title { font-weight: bold; font-size: 10px; margin-bottom: 4px; border-bottom: 1px solid #333; padding-bottom: 2px; }
    .card-item { display: flex; margin: 2px 0; font-size: 10px; width: 100%; }
    .card-label { font-weight: 600; min-width: 75px; flex-shrink: 0; }
    .card-value { flex: 1; word-break: break-word; overflow: hidden; }
    table { width: 100%; border-collapse: collapse; margin: 10px 0; table-layout: fixed; }
    th, td { border: 1px solid #ccc; padding: 4px 3px; text-align: left; font-size: 10px; word-break: break-word; }
    th { background: #e5e5e5; font-weight: bold; }
    .images-section { border: 1px solid #333; padding: 8px; margin: 10px 0; background: #fafafa; }
    .images-title { font-weight: bold; font-size: 10px; margin-bottom: 6px; border-bottom: 1px solid #333; padding-bottom: 2px; }
    .images-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; margin-top: 6px; width: 100%; }
    .image-item { border: 1px solid #ccc; padding: 2px; text-align: center; word-break: break-word; }
    .image-item img { max-width: 100%; height: auto; max-height: 100px; margin-bottom: 2px; display: block; }
    .image-name { font-size: 8px; word-break: break-word; color: #666; }
    .signature-block { margin-top: 15px; display: grid; grid-template-columns: 1fr 1fr; gap: 20px; font-size: 10px; width: 100%; }
    .sig-item { text-align: center; }
    .sig-line { height: 40px; border-bottom: 1px solid #333; margin-bottom: 3px; }
    html, body { width: 100%; overflow-x: hidden; }
  `;

  // Build items table rows
  let itemsHtml = '';
  data.items.forEach((item, idx) => {
    itemsHtml += `<tr><td style="text-align: center;">${idx + 1}</td><td style="font-size: 10px;">${escapeHtml(item.item_type)}</td><td>${escapeHtml(item.name)}</td><td style="text-align: right;">${item.qty}</td><td style="text-align: right;">₹${item.price.toFixed(2)}</td><td style="text-align: right;">₹${item.discount.toFixed(2)}</td><td style="text-align: right; font-weight: bold;">₹${item.total.toFixed(2)}</td></tr>`;
  });

  // Build images section
  let imagesHtml = '';
  if (data.savedImages && data.savedImages.length > 0) {
    imagesHtml = `<div class="images-section"><div class="images-title">Images</div><div class="images-grid">`;
    data.savedImages.forEach(img => {
      imagesHtml += `<div class="image-item"><img src="${img.file_url}" alt="Job card image" /><div class="image-name">${escapeHtml(img.file_name || 'Image')}</div></div>`;
    });
    imagesHtml += `</div></div>`;
  }

  // Write complete document
  const htmlContent = `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Job Card - ${data.jobCardNumber}</title><style>${styleContent}</style></head><body><div class="container">${data.logoBase64 ? `<div class="logo-header"><img src="${data.logoBase64}" alt="CarWhizz Logo" /></div>` : ''}</div><h2>Job Card</h2><div class="job-info">${data.jobCardNumber}</div><div class="cards-row"><div class="card"><div class="card-title">Customer Details</div><div class="card-item"><span class="card-label">Name:</span><span class="card-value">${escapeHtml(data.customerName)}</span></div><div class="card-item"><span class="card-label">Vehicle:</span><span class="card-value">${escapeHtml(data.vehicleInfo)}</span></div></div><div class="card"><div class="card-title">Job Info</div><div class="card-item"><span class="card-label">Assigned:</span><span class="card-value">${escapeHtml(data.assignedToUser)}</span></div><div class="card-item"><span class="card-label">Priority:</span><span class="card-value">${escapeHtml(data.priority)}</span></div><div class="card-item"><span class="card-label">Expected:</span><span class="card-value">${escapeHtml(data.expectedDate)}</span></div></div></div><div class="inspection-row"><div class="card"><div class="card-title">Body Inspection</div><div style="padding: 6px; line-height: 1.4; min-height: 60px; font-size: 10px;">${escapeHtml(data.description)}</div></div><div class="card"><div class="card-title">Mechanical Inspection</div><div style="padding: 6px; line-height: 1.4; min-height: 60px; font-size: 10px;">${escapeHtml(data.details)}</div></div></div><div style="border: 1px solid #333; padding: 10px; margin: 12px 0; background: #fafafa;"><div style="font-weight: bold; font-size: 11px; margin-bottom: 6px; border-bottom: 1px solid #333; padding-bottom: 3px;">Items & Services</div><table style="width: 100%; border-collapse: collapse; margin: 6px 0; font-size: 11px;"><thead><tr style="background: #e5e5e5;"><th style="border: 1px solid #ccc; padding: 4px; text-align: center; width: 25px;">#</th><th style="border: 1px solid #ccc; padding: 4px; width: 50px;">Type</th><th style="border: 1px solid #ccc; padding: 4px;">Description</th><th style="border: 1px solid #ccc; padding: 4px; text-align: right; width: 50px;">Qty</th><th style="border: 1px solid #ccc; padding: 4px; text-align: right; width: 60px;">Price</th><th style="border: 1px solid #ccc; padding: 4px; text-align: right; width: 60px;">Discount</th><th style="border: 1px solid #ccc; padding: 4px; text-align: right; width: 60px;">Total</th></tr></thead><tbody>${itemsHtml}<tr style="background: #e5e5e5; font-weight: bold;"><td colspan="6" style="border: 1px solid #ccc; padding: 6px; text-align: right;">GRAND TOTAL:</td><td style="border: 1px solid #ccc; padding: 6px; text-align: right; font-size: 12px;">₹${data.totalAmount.toFixed(2)}</td></tr></tbody></table></div>${imagesHtml}<div class="signature-block"><div class="sig-item"><div class="sig-line"></div><div>Authorized By</div></div><div class="sig-item"><div class="sig-line"></div><div>Customer Signature</div></div></div></body></html>`;

  win.document.write(htmlContent);
  win.document.close();
  setTimeout(() => win.print(), 500);
}
