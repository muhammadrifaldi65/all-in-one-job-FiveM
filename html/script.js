(function () {

  const wrap = document.getElementById('wrap');
  const rowsEl = document.getElementById('ledger-rows');
  const btnClose = document.getElementById('btn-close');
  const btnSell = document.getElementById('btn-sell');

  const sealFill = document.getElementById('seal-fill');
  const sealAmount = document.getElementById('seal-amount');
  const treasuryStatus = document.getElementById('treasury-status');

  const sumCount = document.getElementById('sum-count');
  const sumTotal = document.getElementById('sum-total');

  const SEAL_CIRCUMFERENCE = 339.3;

  let items = [];
  let treasury = 0;
  let qtyMap = {}; // item -> selected qty

  function fmtRp(value) {
    return 'Rp' + Math.floor(value).toLocaleString('id-ID');
  }

  function postNui(endpoint, body) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body || {}),
    }).then((r) => r.json()).catch(() => null);
  }

  function cartTotal() {
    let total = 0;
    let count = 0;

    for (const entry of items) {
      const qty = qtyMap[entry.item] || 0;
      if (qty > 0) {
        total += qty * entry.price;
        count += 1;
      }
    }

    return { total, count };
  }

  function updateSeal() {
    const { total, count } = cartTotal();

    sealAmount.textContent = Math.floor(treasury).toLocaleString('id-ID');
    sumCount.textContent = count;
    sumTotal.textContent = fmtRp(total);

    let ratio = 1;
    let statusClass = 'status-ok';
    let statusText = 'Dana mencukupi';

    if (treasury <= 0) {
      ratio = 0;
      statusClass = 'status-empty';
      statusText = 'Dana pemerintah habis, coba lagi nanti.';
    } else if (total > treasury) {
      ratio = Math.max(treasury / Math.max(total, 1), 0.05);
      statusClass = 'status-warn';
      statusText = 'Dana tidak cukup untuk jumlah ini.';
    } else if (treasury < 5000) {
      statusClass = 'status-warn';
      statusText = 'Dana pemerintah menipis.';
    }

    sealFill.setAttribute(
      'stroke-dasharray',
      SEAL_CIRCUMFERENCE
    );
    sealFill.setAttribute(
      'stroke-dashoffset',
      String(SEAL_CIRCUMFERENCE * (1 - ratio))
    );

    sealFill.style.stroke =
      statusClass === 'status-ok' ? 'var(--green-ok)' :
      statusClass === 'status-warn' ? 'var(--amber-warn)' :
      'var(--red-empty)';

    treasuryStatus.className = statusClass;
    treasuryStatus.textContent = statusText;

    const disableSell = treasury <= 0 || count === 0 || total > treasury;
    btnSell.disabled = disableSell;
  }

  function renderRows() {
    rowsEl.innerHTML = '';

    for (const entry of items) {

      qtyMap[entry.item] = qtyMap[entry.item] || 0;

      const row = document.createElement('div');
      row.className = 'ledger-row';
      row.dataset.item = entry.item;

      row.innerHTML = `
        <div class="item-name">
          ${entry.label}
          <span class="item-owned">Kamu punya ${entry.owned}x</span>
        </div>
        <div class="item-price">${fmtRp(entry.price)}</div>
        <div class="qty-control">
          <input
            class="qty-input"
            type="number"
            min="0"
            max="${Math.min(entry.owned, entry.maxPerSell)}"
            value="0"
            inputmode="numeric"
            autocomplete="off"
            aria-label="Jumlah ${entry.label}"
          />
        </div>
        <div class="item-sub">Rp0</div>
      `;

      rowsEl.appendChild(row);

      const qtyInput = row.querySelector('.qty-input');
      const subEl = row.querySelector('.item-sub');

      function refreshRow() {
        const qty = qtyMap[entry.item] || 0;
        qtyInput.value = qty;
        subEl.textContent = fmtRp(qty * entry.price);
        updateSeal();
      }

      qtyInput.addEventListener('input', () => {
        const cap = Math.min(Number(entry.owned) || 0, Number(entry.maxPerSell) || 0);
        let value = parseInt(qtyInput.value, 10);
        if (Number.isNaN(value) || value < 0) value = 0;
        if (value > cap) value = cap;

        qtyMap[entry.item] = value;
        qtyInput.value = value;
        subEl.textContent = fmtRp(value * entry.price);
        updateSeal();
      });

      qtyInput.addEventListener('blur', refreshRow);
    }
  }

  function resetCart() {
    qtyMap = {};
    updateSeal();
  }

  async function submitSale() {
    btnSell.disabled = true;
    btnSell.textContent = 'Memproses...';

    const toSell = items.filter((entry) => (qtyMap[entry.item] || 0) > 0);

    for (const entry of toSell) {

      const qty = qtyMap[entry.item];

      const result = await postNui('zhr_shop:sell', {
        item: entry.item,
        amount: qty,
      });

      if (result && result.success) {
        treasury = result.treasury;
        entry.owned = Math.max(0, entry.owned - qty);
      } else {
        // hentikan proses kalau salah satu gagal (misal dana habis di tengah jalan)
        break;
      }
    }

    resetCart();
    renderRows();
    btnSell.textContent = 'Ajukan Penjualan';
  }

  btnSell.addEventListener('click', submitSale);

  btnClose.addEventListener('click', () => {
    postNui('zhr_shop:close');
    closeUi();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      postNui('zhr_shop:close');
      closeUi();
    }
  });

  function openUi(data) {
    items = data.items || [];
    treasury = data.treasury || 0;
    resetCart();
    renderRows();
    updateSeal();
    wrap.classList.remove('hidden');
  }

  function closeUi() {
    wrap.classList.add('hidden');
  }

  window.addEventListener('message', (event) => {
    const data = event.data;

    if (!data || !data.action) {
      return;
    }

    if (data.action === 'open') {
      openUi(data);
    } else if (data.action === 'close') {
      closeUi();
    } else if (data.action === 'updateTreasury') {
      treasury = data.treasury;
      updateSeal();
    }
  });

})();
