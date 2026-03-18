<!-- ============================================================
     SHARED > SEARCHABLE DROPDOWN
     Purpose: Reusable dropdown with search/filter + add new button
     Props: items, value, placeholder, onSelect, onAdd
     ============================================================ -->

<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  export let items: { id: string; name: string }[] = [];
  export let value: string = '';
  export let placeholder: string = 'Select...';
  export let label: string = '';

  const dispatch = createEventDispatcher();

  let search = '';
  let open = false;
  let inputEl: HTMLInputElement;

  $: selectedItem = items.find(i => i.id === value);
  $: displayText = selectedItem ? selectedItem.name : '';
  $: filtered = search
    ? items.filter(i => i.name.toLowerCase().includes(search.toLowerCase()))
    : items;

  function toggle() {
    open = !open;
    if (open) {
      search = '';
      setTimeout(() => inputEl?.focus(), 50);
    }
  }

  function select(item: { id: string; name: string }) {
    value = item.id;
    dispatch('select', item);
    open = false;
    search = '';
  }

  function handleAdd() {
    dispatch('add');
  }

  function handleEdit(item: { id: string; name: string }) {
    dispatch('edit', item);
  }

  function handleClickOutside(e: MouseEvent) {
    const target = e.target as HTMLElement;
    if (!target.closest('.searchable-dropdown')) {
      open = false;
    }
  }
</script>

<svelte:window on:click={handleClickOutside} />

<div class="searchable-dropdown">
  {#if label}
    <label class="dropdown-label">{label}</label>
  {/if}
  <div class="dropdown-trigger" on:click={toggle} on:keydown={e => e.key === 'Enter' && toggle()} role="button" tabindex="0">
    <span class:placeholder={!selectedItem}>
      {displayText || placeholder}
    </span>
    <svg class="chevron" class:open viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14">
      <polyline points="6 9 12 15 18 9"/>
    </svg>
  </div>

  {#if open}
    <div class="dropdown-panel">
      <div class="search-row">
        <input
          bind:this={inputEl}
          bind:value={search}
          type="text"
          placeholder="Search..."
          class="search-input"
          on:click|stopPropagation
        />
        <button class="add-btn" title="Add new" on:click|stopPropagation={handleAdd}>+</button>
      </div>
      <div class="options-list">
        {#if filtered.length === 0}
          <div class="no-results">No results</div>
        {:else}
          {#each filtered as item (item.id)}
            <div class="option-row">
              <button
                class="option-item"
                class:selected={item.id === value}
                on:click|stopPropagation={() => select(item)}
              >
                {item.name}
              </button>
              <button class="edit-btn" title="Edit" on:click|stopPropagation={() => handleEdit(item)}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="12" height="12">
                  <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                  <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
                </svg>
              </button>
            </div>
          {/each}
        {/if}
      </div>
    </div>
  {/if}
</div>

<style>
  .searchable-dropdown {
    position: relative;
    width: 100%;
  }

  .dropdown-label {
    display: block;
    font-size: 12px;
    font-weight: 600;
    color: #374151;
    margin-bottom: 4px;
  }

  .dropdown-trigger {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 10px;
    background: white;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    color: #111827;
    min-height: 36px;
    transition: border-color 0.15s;
  }

  .dropdown-trigger:hover {
    border-color: #C41E3A;
  }

  .dropdown-trigger .placeholder {
    color: #9ca3af;
  }

  .chevron {
    flex-shrink: 0;
    transition: transform 0.2s;
  }

  .chevron.open {
    transform: rotate(180deg);
  }

  .dropdown-panel {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    margin-top: 4px;
    background: white;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
    z-index: 500;
    overflow: hidden;
  }

  .search-row {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 6px;
    border-bottom: 1px solid #f3f4f6;
  }

  .search-input {
    flex: 1;
    padding: 6px 8px;
    border: 1px solid #e5e7eb;
    border-radius: 4px;
    font-size: 12px;
    outline: none;
  }

  .search-input:focus {
    border-color: #C41E3A;
  }

  .add-btn {
    width: 30px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #C41E3A;
    color: white;
    border: none;
    border-radius: 6px;
    font-size: 18px;
    font-weight: 700;
    cursor: pointer;
    flex-shrink: 0;
    transition: background 0.15s;
  }

  .add-btn:hover {
    background: #C41E3A;
  }

  .options-list {
    max-height: 180px;
    overflow-y: auto;
  }

  .option-row {
    display: flex;
    align-items: center;
  }

  .option-item {
    flex: 1;
    text-align: left;
    padding: 8px 12px;
    border: none;
    background: none;
    font-size: 13px;
    color: #374151;
    cursor: pointer;
    transition: background 0.1s;
  }

  .edit-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 26px;
    height: 26px;
    background: none;
    border: none;
    border-radius: 4px;
    color: #9ca3af;
    cursor: pointer;
    flex-shrink: 0;
    margin-right: 6px;
    transition: all 0.15s;
  }

  .edit-btn:hover {
    background: #fff7ed;
    color: #C41E3A;
  }

  .option-row:hover .option-item {
    background: #fff7ed;
    color: #C41E3A;
  }

  .option-item:hover {
    background: #fff7ed;
    color: #C41E3A;
  }

  .option-item.selected {
    background: #FFF7ED;
    color: #C41E3A;
    font-weight: 600;
  }

  .no-results {
    padding: 12px;
    text-align: center;
    color: #9ca3af;
    font-size: 13px;
  }
</style>
