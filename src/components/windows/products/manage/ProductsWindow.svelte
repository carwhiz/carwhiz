<!-- ============================================================
     PRODUCTS > MANAGE > PRODUCTS WINDOW
     Purpose: Product listing page with table and Create button
     Section: Products > Manage > Products
     Window ID: products-products
     ============================================================ -->

<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { windowStore } from '../../../../stores/windowStore';

  interface ProductRow {
    id: string;
    product_name: string;
    product_type: string;
    applicability: string | null;
    unit_qty: number | null;
    current_cost: number | null;
    sales_price: number | null;
    first_level_discount: number | null;
    second_level_discount: number | null;
    third_level_discount: number | null;
    barcode: string | null;
    part_number: string | null;
    expiry_date: string | null;
    file_path: string | null;
    current_stock: number | null;
    minimum_stock: number | null;
    maximum_stock: number | null;
    reorder_level: number | null;
    created_at: string;
    vehicles: { model_name: string } | null;
    units: { name: string } | null;
    brands: { name: string } | null;
  }

  let products: ProductRow[] = [];
  let avgCostMap: Record<string, number> = {};
  let loading = true;
  let error = '';
  let searchQuery = '';

  $: filteredProducts = searchQuery
    ? products.filter(p =>
        p.product_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        p.product_type.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : products;

  onMount(() => {
    loadProducts();
  });

  async function loadProducts() {
    loading = true;
    error = '';

    const { data, error: dbError } = await supabase
      .from('products')
      .select(`
        id, product_name, product_type, applicability,
        unit_qty, current_cost, sales_price,
        first_level_discount, second_level_discount, third_level_discount,
        barcode, part_number, expiry_date, file_path, created_at,
        current_stock, minimum_stock, maximum_stock, reorder_level,
        vehicles ( model_name ),
        units ( name ),
        brands ( name )
      `)
      .order('created_at', { ascending: false });

    loading = false;

    if (dbError) {
      error = dbError.message;
      return;
    }

    products = (data as unknown as ProductRow[]) || [];

    // Calculate average purchase cost per product from purchase_items
    const { data: purchaseItems } = await supabase
      .from('purchase_items')
      .select('product_id, qty, rate');

    const costAgg: Record<string, { totalVal: number; totalQty: number }> = {};
    for (const pi of (purchaseItems || [])) {
      if (!pi.product_id) continue;
      if (!costAgg[pi.product_id]) costAgg[pi.product_id] = { totalVal: 0, totalQty: 0 };
      costAgg[pi.product_id].totalVal += (pi.rate || 0) * (pi.qty || 0);
      costAgg[pi.product_id].totalQty += (pi.qty || 0);
    }
    const map: Record<string, number> = {};
    for (const [pid, agg] of Object.entries(costAgg)) {
      map[pid] = agg.totalQty > 0 ? Math.round((agg.totalVal / agg.totalQty) * 100) / 100 : 0;
    }
    avgCostMap = map;
  }

  function openCreateProduct() {
    windowStore.open('products-create-product', 'Create Product');
  }

  function openEditProduct(id: string, name: string) {
    windowStore.open('products-edit-product-' + id, 'Edit: ' + name);
  }

  function formatPrice(val: number | null) {
    if (val === null || val === undefined) return '—';
    return val.toFixed(2);
  }

  function formatType(t: string) {
    return t.charAt(0).toUpperCase() + t.slice(1);
  }

  export { loadProducts };
</script>

<div class="products-window">
  <!-- Top Controls -->
  <div class="top-controls">
    <div class="title-area">
      <h2>Products</h2>
      <span class="record-count">{products.length} record{products.length !== 1 ? 's' : ''}</span>
    </div>
    <div class="actions-area">
      <div class="search-box">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
        </svg>
        <input type="text" bind:value={searchQuery} placeholder="Search products..." />
      </div>
      <button class="btn-create" on:click={openCreateProduct}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16">
          <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
        </svg>
        Create Product
      </button>
    </div>
  </div>

  <!-- Table Section -->
  <div class="table-container">
    {#if loading}
      <div class="table-status">Loading products...</div>
    {:else if error}
      <div class="table-status error">{error}</div>
    {:else if filteredProducts.length === 0}
      <div class="table-status">
        {searchQuery ? 'No products match your search' : 'No products created yet'}
      </div>
    {:else}
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Product Name</th>
            <th>Type</th>
            <th>Applicability</th>
            <th>Vehicle</th>
            <th>Unit</th>
            <th>Qty</th>
            <th>Stock</th>
            <th>Min</th>
            <th>Max</th>
            <th>Reorder</th>
            <th>Cost</th>
            <th>Avg Cost</th>
            <th>Price</th>
            <th>D1%</th>
            <th>D2%</th>
            <th>D3%</th>
            <th>Part No.</th>
            <th>Brand</th>
            <th>Barcode</th>
            <th>Expiry</th>
            <th>File</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredProducts as product, i (product.id)}
            <tr>
              <td class="num">{i + 1}</td>
              <td class="name">{product.product_name}</td>
              <td><span class="type-badge {product.product_type}">{formatType(product.product_type)}</span></td>
              <td>{product.applicability ? formatType(product.applicability) : '—'}</td>
              <td>{product.vehicles?.model_name || '—'}</td>
              <td>{product.units?.name || '—'}</td>
              <td>{product.unit_qty ?? '—'}</td>
              <td class:low-stock={product.current_stock !== null && product.reorder_level !== null && product.current_stock <= product.reorder_level}>{product.current_stock ?? 0}</td>
              <td>{product.minimum_stock ?? 0}</td>
              <td>{product.maximum_stock ?? 0}</td>
              <td>{product.reorder_level ?? 0}</td>
              <td>{formatPrice(product.current_cost)}</td>
              <td>{formatPrice(avgCostMap[product.id] ?? null)}</td>
              <td>{formatPrice(product.sales_price)}</td>
              <td>{product.first_level_discount ?? '—'}</td>
              <td>{product.second_level_discount ?? '—'}</td>
              <td>{product.third_level_discount ?? '—'}</td>
              <td>{product.part_number ?? '—'}</td>
              <td>{product.brands?.name || '—'}</td>
              <td>{product.barcode ?? '—'}</td>
              <td>{product.expiry_date ?? '—'}</td>
              <td>
                {#if product.file_path}
                  <span class="file-indicator" title="Has file">📎</span>
                {:else}
                  —
                {/if}
              </td>
              <td class="actions">
                <button class="btn-edit" title="Edit" on:click={() => openEditProduct(product.id, product.product_name)}>
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
                    <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                    <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
                  </svg>
                  Edit
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </div>
</div>

<style>
  .products-window {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    background: #fafafa;
  }

  .top-controls {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    background: white;
    border-bottom: 1px solid #e5e7eb;
    flex-shrink: 0;
  }

  .title-area {
    display: flex;
    align-items: baseline;
    gap: 10px;
  }

  .title-area h2 {
    margin: 0;
    font-size: 18px;
    font-weight: 700;
    color: #111827;
  }

  .record-count {
    font-size: 12px;
    color: #9ca3af;
    font-weight: 500;
  }

  .actions-area {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .search-box {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
  }

  .search-box svg {
    color: #9ca3af;
    flex-shrink: 0;
  }

  .search-box input {
    border: none;
    background: none;
    outline: none;
    font-size: 13px;
    width: 180px;
    color: #374151;
  }

  .btn-create {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 16px;
    background: #F97316;
    color: white;
    border: none;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
    white-space: nowrap;
  }

  .btn-create:hover {
    background: #EA580C;
  }

  .table-container {
    flex: 1;
    overflow: auto;
  }

  .table-status {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 200px;
    color: #9ca3af;
    font-size: 14px;
  }

  .table-status.error {
    color: #ef4444;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }

  thead {
    position: sticky;
    top: 0;
    z-index: 2;
  }

  th {
    background: #f9fafb;
    padding: 10px 10px;
    text-align: left;
    font-weight: 600;
    color: #6b7280;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    border-bottom: 1px solid #e5e7eb;
    white-space: nowrap;
  }

  td {
    padding: 9px 10px;
    color: #374151;
    border-bottom: 1px solid #f3f4f6;
    white-space: nowrap;
  }

  tr:hover td {
    background: #fffbf5;
  }

  .num {
    color: #9ca3af;
    width: 36px;
  }

  .name {
    font-weight: 600;
    color: #111827;
  }

  .type-badge {
    display: inline-block;
    padding: 2px 8px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.03em;
  }

  .type-badge.product {
    background: #dbeafe;
    color: #1d4ed8;
  }

  .type-badge.service {
    background: #f3e8ff;
    color: #7c3aed;
  }

  .type-badge.consumable {
    background: #dcfce7;
    color: #16a34a;
  }

  .low-stock {
    color: #dc2626;
    font-weight: 700;
  }

  .file-indicator {
    font-size: 14px;
  }

  .actions {
    width: 80px;
  }

  .btn-edit {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 5px 10px;
    background: #fff7ed;
    border: 1px solid #fed7aa;
    border-radius: 5px;
    font-size: 12px;
    font-weight: 500;
    color: #EA580C;
    cursor: pointer;
    transition: all 0.15s;
  }

  .btn-edit:hover {
    background: #F97316;
    color: white;
    border-color: #F97316;
  }
</style>
