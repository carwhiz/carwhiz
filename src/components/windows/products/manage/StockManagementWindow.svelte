<script lang="ts">
  import { onMount } from 'svelte';
  import { supabase } from '../../../../lib/supabaseClient';
  import { authStore } from '../../../../stores/authStore';
  import { windowStore } from '../../../../stores/windowStore';
  import { canUserEditResource } from '../../../../lib/services/permissionService';

  interface Product {
    id: string;
    product_name: string;
    barcode: string | null;
    current_stock: number;
    unit_qty: number;
    units: { name: string } | null;
  }

  let products: Product[] = [];
  let filteredProducts: Product[] = [];
  let selectedProduct: Product | null = null;
  let loading = true;
  let error = '';
  let adjusting = false;
  let searchQuery = '';
  let selectedProductId: string | null = null;
  let adjustmentAmount = 0;
  let adjustmentReason = '';
  let canAdjustStock = false;
  let showAdjustModal = false;

  $: filteredProducts = searchQuery
    ? products.filter(p =>
        p.product_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (p.barcode || '').toLowerCase().includes(searchQuery.toLowerCase())
      )
    : products;

  onMount(async () => {
    // Check permissions
    if ($authStore.user) {
      const hasPermission = await canUserEditResource($authStore.user.id, 'products-stock-management');
      canAdjustStock = hasPermission;
    }

    // Load products with stock quantities
    await loadProducts();
  });

  function openAdjustModal(product: Product) {
    selectedProduct = product;
    selectedProductId = product.id;
    adjustmentAmount = 0;
    adjustmentReason = '';
    showAdjustModal = true;
  }

  function closeAdjustModal() {
    showAdjustModal = false;
    selectedProduct = null;
    selectedProductId = null;
    adjustmentAmount = 0;
    adjustmentReason = '';
  }

  async function loadProducts() {
    try {
      loading = true;
      error = '';

      const { data, error: fetchError } = await supabase
        .from('products')
        .select(`
          id,
          product_name,
          barcode,
          current_stock,
          unit_qty,
          units ( name )
        `)
        .neq('product_type', 'service')
        .order('product_name');

      if (fetchError) throw fetchError;
      
      // Ensure all current_stock values are valid numbers
      products = (data || []).map(p => ({
        ...p,
        current_stock: Number(p.current_stock) || 0
      }));
    } catch (err: any) {
      error = err.message || 'Failed to load products';
      console.error('Error loading products:', err);
    } finally {
      loading = false;
    }
  }

  async function adjustStock() {
    if (!selectedProductId || !adjustmentAmount || !adjustmentReason) {
      error = 'Please fill in all fields';
      return;
    }

    if (!canAdjustStock) {
      error = 'You do not have permission to adjust stock';
      return;
    }

    if (!$authStore.user) {
      error = 'User not authenticated';
      return;
    }

    try {
      adjusting = true;
      error = '';

      const product = products.find(p => p.id === selectedProductId);
      if (!product) {
        error = 'Product not found';
        return;
      }

      // Ensure adjustment amount is a number
      const targetQty = Number(adjustmentAmount);
      if (isNaN(targetQty)) {
        error = 'Invalid stock quantity';
        return;
      }
      
      if (targetQty < 0) {
        error = 'Stock quantity cannot be negative';
        return;
      }

      // Calculate the difference to add/subtract
      const currentQty = Number(product.current_stock);
      const adjustmentInItems = targetQty - currentQty;
      
      console.log('Stock Adjustment:', { currentQty, targetQty, adjustmentInItems });

      // Update product stock via stock_movements (which triggers automatic update to current_stock)
      const { error: movementError } = await supabase
        .from('stock_movements')
        .insert({
          product_id: selectedProductId,
          qty: adjustmentInItems,
          movement_type: 'manual_adjustment',
          reason: adjustmentReason,
          created_by: $authStore.user.id
        });

      if (movementError) throw movementError;

      // Also directly update products.current_stock to ensure it's correct
      const { error: updateError } = await supabase
        .from('products')
        .update({ 
          current_stock: targetQty,
          updated_by: $authStore.user.id,
          updated_at: new Date().toISOString()
        })
        .eq('id', selectedProductId);

      if (updateError) throw updateError;

      // Reload products to show updated quantities
      await loadProducts();

      // Close modal and reset form
      closeAdjustModal();

      error = ''; // Clear any errors
    } catch (err: any) {
      error = err.message || 'Failed to adjust stock';
      console.error('Error adjusting stock:', err);
    } finally {
      adjusting = false;
    }
  }
</script>

<div class="stock-management">
    {#if error}
      <div class="error-banner">{error}</div>
    {/if}

    <div class="products-table">
      <div class="table-header">
        <h3>Product Stock Levels</h3>
        <div class="search-box">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="8"/>
            <path d="m21 21-4.35-4.35"/>
          </svg>
          <input
            type="text"
            bind:value={searchQuery}
            placeholder="Search by product name or barcode..."
          />
        </div>
      </div>

      {#if loading}
        <div class="table-status">Loading products...</div>
      {:else if filteredProducts.length === 0}
        <div class="table-status">{searchQuery ? 'No products found' : 'No products found'}</div>
      {:else}
        <div class="table-container">
          <table>
            <thead>
              <tr>
                <th>Product Name</th>
                <th>Barcode</th>
                <th>Current Stock</th>
                <th>Unit Qty</th>
                <th>Unit</th>
                <th class="actions">Action</th>
              </tr>
            </thead>
            <tbody>
              {#each filteredProducts as product}
                <tr class:low-stock={product.current_stock < 10}>
                  <td>{product.product_name}</td>
                  <td>{product.barcode || '-'}</td>
                  <td class="stock-qty">{product.current_stock}</td>
                  <td>{product.unit_qty}</td>
                  <td>{product.units?.name || '-'}</td>
                  <td>
                    <button
                      class="btn-adjust"
                      on:click={() => openAdjustModal(product)}
                      disabled={!canAdjustStock}
                      title={canAdjustStock ? 'Adjust stock' : 'No permission'}
                    >
                      Adjust
                    </button>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>
      {/if}
    </div>

    {#if !canAdjustStock}
      <div class="permission-warning">
        ⚠️ You do not have permission to adjust stock. Contact your administrator.
      </div>
    {/if}
  </div>

  <!-- Adjust Stock Modal -->
  {#if showAdjustModal && selectedProductId}
    <div class="modal-overlay" on:click={closeAdjustModal}>
      <div class="modal-content" on:click|stopPropagation>
        <div class="modal-header">
          <h3>Adjust Stock</h3>
          <button class="btn-close" on:click={closeAdjustModal}>&times;</button>
        </div>

        <div class="modal-body">
          {#if error}
            <div class="error-banner">{error}</div>
          {/if}

          {#if selectedProduct}
            <div class="product-details">
              <div class="detail-row">
                <label>Product Name:</label>
                <span>{selectedProduct.product_name}</span>
              </div>
              <div class="detail-row">
                <label>Barcode:</label>
                <span>{selectedProduct.barcode || '-'}</span>
              </div>
              <div class="detail-row">
                <label>Unit:</label>
                <span>{selectedProduct.units?.name || '-'}</span>
              </div>
              <div class="detail-row">
                <label>Unit Qty:</label>
                <span>{selectedProduct.unit_qty}</span>
              </div>
              <div class="detail-row">
                <label>Current Stock:</label>
                <span class="highlight">{selectedProduct.current_stock}</span>
              </div>
            </div>

            <hr style="margin: 12px 0; border: none; border-top: 1px solid #e5e7eb;">

            <div class="form-group">
              <label>Set Stock To (items):</label>
              <input
                type="number"
                bind:value={adjustmentAmount}
                placeholder="Enter exact stock quantity in items"
                disabled={adjusting}
              />
              <small style="color: #999; font-size: 12px; margin-top: 4px; display: block;">
                Current: {selectedProduct.current_stock} items
              </small>
            </div>

            <div class="form-group">
              <label>Reason:</label>
              <input
                type="text"
                bind:value={adjustmentReason}
                placeholder="e.g., Stock count correction, damage, etc."
                disabled={adjusting}
              />
            </div>
          {:else}
            <div style="color: #999; text-align: center; padding: 20px;">
              Product not found
            </div>
          {/if}
        </div>

        <div class="modal-footer">
          <button class="btn-cancel" on:click={closeAdjustModal} disabled={adjusting}>
            Cancel
          </button>
          <button
            class="btn-primary"
            on:click={adjustStock}
            disabled={adjusting || !selectedProductId || !adjustmentAmount || !adjustmentReason}
          >
            {adjusting ? 'Adjusting...' : 'Confirm Adjustment'}
          </button>
        </div>
      </div>
    </div>
  {/if}

<style>
  .stock-management {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .error-banner {
    background-color: #fee;
    border-bottom: 1px solid #fcc;
    color: #c33;
    padding: 8px 16px;
    font-size: 13px;
    flex-shrink: 0;
  }

  .products-table {
    display: flex;
    flex-direction: column;
    flex: 1;
    overflow: hidden;
  }

  .table-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 16px;
    border-bottom: 1px solid #e5e7eb;
    background: #fff;
    flex-shrink: 0;
  }

  .table-header h3 {
    margin: 0;
    font-size: 14px;
    color: #333;
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

  .table-container {
    flex: 1;
    overflow: auto;
    width: 100%;
    box-sizing: border-box;
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
    padding: 10px;
    text-align: left;
    font-weight: 600;
    color: #6b7280;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.03em;
    border-bottom: 1px solid #e5e7eb;
    border-right: 1px solid #e5e7eb;
    white-space: nowrap;
  }

  td {
    padding: 9px 10px;
    color: #374151;
    border-bottom: 1px solid #f3f4f6;
    border-right: 1px solid #e5e7eb;
    white-space: nowrap;
  }

  tr:hover td {
    background: #fffbf5;
  }

  tr.low-stock td {
    background: #fffacd;
  }

  .stock-qty {
    font-weight: 600;
    color: #111827;
  }

  .actions {
    width: 80px;
  }

  .btn-adjust {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 5px 10px;
    background: #fff7ed;
    border: 1px solid #fed7aa;
    border-radius: 5px;
    font-size: 12px;
    font-weight: 500;
    color: #C41E3A;
    cursor: pointer;
    transition: all 0.15s;
  }

  .btn-adjust:hover:not(:disabled) {
    background: #C41E3A;
    color: white;
    border-color: #C41E3A;
  }

  .btn-adjust:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .table-status {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 200px;
    color: #9ca3af;
    font-size: 14px;
  }

  .permission-warning {
    background-color: #fff3cd;
    border-top: 1px solid #ffc107;
    color: #856404;
    padding: 8px 16px;
    font-size: 13px;
    text-align: center;
    flex-shrink: 0;
  }

  /* Modal Styles */
  .modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }

  .modal-content {
    background: white;
    border-radius: 8px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
    max-width: 400px;
    width: 90%;
    max-height: 80vh;
    overflow-y: auto;
  }

  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    border-bottom: 1px solid #eee;
  }

  .modal-header h3 {
    margin: 0;
    font-size: 15px;
    color: #333;
  }

  .btn-close {
    background: none;
    border: none;
    font-size: 20px;
    color: #999;
    cursor: pointer;
    padding: 0;
    width: 28px;
    height: 28px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .btn-close:hover {
    color: #333;
  }

  .modal-body {
    padding: 16px;
  }

  .modal-footer {
    display: flex;
    gap: 10px;
    padding: 12px 16px;
    border-top: 1px solid #eee;
    justify-content: flex-end;
  }

  .form-group {
    margin-bottom: 12px;
  }

  .form-group:last-child {
    margin-bottom: 0;
  }

  .form-group label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    margin-bottom: 4px;
    color: #555;
  }

  .product-info {
    padding: 8px 10px;
    background: #f9f9f9;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 13px;
    color: #333;
  }

  .product-details {
    background: #f9f9f9;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 12px 10px;
    margin-bottom: 12px;
  }

  .detail-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 6px 0;
    font-size: 13px;
    border-bottom: 1px solid #e5e7eb;
  }

  .detail-row:last-child {
    border-bottom: none;
  }

  .detail-row label {
    font-weight: 600;
    color: #555;
    flex: 0 0 140px;
  }

  .detail-row span {
    color: #333;
    text-align: right;
  }

  .detail-row span.highlight {
    color: #C41E3A;
    font-weight: 600;
  }

  .form-group input {
    width: 100%;
    padding: 8px 10px;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 13px;
    box-sizing: border-box;
  }

  .form-group input:disabled {
    background-color: #f5f5f5;
    cursor: not-allowed;
    color: #999;
  }

  .btn-primary {
    background-color: #4caf50;
    color: white;
    border: none;
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
    transition: background-color 0.2s;
  }

  .btn-primary:hover:not(:disabled) {
    background-color: #45a049;
  }

  .btn-primary:disabled {
    background-color: #ccc;
    cursor: not-allowed;
  }

  .btn-cancel {
    background-color: #e0e0e0;
    color: #333;
    border: none;
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 600;
    transition: background-color 0.2s;
  }

  .btn-cancel:hover:not(:disabled) {
    background-color: #d0d0d0;
  }

  .btn-cancel:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
</style>
