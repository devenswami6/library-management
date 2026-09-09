// assets/js/main.js - Interactive Scripts with Notification Dropdown & Light/Dark Theme Switcher

document.addEventListener('DOMContentLoaded', () => {
    // 1. Light / Dark Theme Switcher Logic
    const themeBtn = document.getElementById('themeToggleBtn');
    const htmlElem = document.documentElement;

    const savedTheme = localStorage.getItem('studyspace_theme') || 'light';
    setTheme(savedTheme);

    if (themeBtn) {
        themeBtn.addEventListener('click', () => {
            const currentTheme = htmlElem.getAttribute('data-theme');
            const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
            setTheme(newTheme);
        });
    }

    function setTheme(theme) {
        htmlElem.setAttribute('data-theme', theme);
        localStorage.setItem('studyspace_theme', theme);
        if (themeBtn) {
            themeBtn.innerHTML = theme === 'dark' ? '<i class="fas fa-sun" style="color:#fbbf24;"></i>' : '<i class="fas fa-moon"></i>';
        }
    }

    // 2. Notification Bell Dropdown Popup Toggle
    const notifBellBtn = document.getElementById('notifBellBtn');
    const notifDropdown = document.getElementById('notifDropdown');

    if (notifBellBtn && notifDropdown) {
        notifBellBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            notifDropdown.classList.toggle('active');
        });

        document.addEventListener('click', (e) => {
            if (!notifDropdown.contains(e.target) && e.target !== notifBellBtn) {
                notifDropdown.classList.remove('active');
            }
        });
    }

    // 3. Tab Switching Functionality
    const tabBtns = document.querySelectorAll('.tab-btn');
    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const targetPaneId = btn.getAttribute('data-tab');
            if (!targetPaneId) return;

            const container = btn.closest('.tab-navigation') || btn.parentElement;
            container.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));

            const parentSection = btn.closest('.card') || document;
            parentSection.querySelectorAll('.tab-pane').forEach(pane => pane.classList.remove('active'));

            btn.classList.add('active');
            const targetPane = document.getElementById(targetPaneId);
            if (targetPane) {
                targetPane.classList.add('active');
            }
        });
    });

    // 4. Modals Control
    window.openModal = function(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) modal.classList.add('active');
    };

    window.closeModal = function(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) modal.classList.remove('active');
    };

    document.querySelectorAll('.modal-close, .btn-cancel-modal').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const modal = e.target.closest('.modal-overlay');
            if (modal) modal.classList.remove('active');
        });
    });

    document.querySelectorAll('.modal-overlay').forEach(modal => {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.classList.remove('active');
            }
        });
    });

    // 5. Shift selector listener for Admin Seat Map Grid
    const shiftSelector = document.getElementById('seatMapShiftSelector');
    if (shiftSelector) {
        shiftSelector.addEventListener('change', (e) => {
            loadSeatMatrix(e.target.value);
        });
        loadSeatMatrix(shiftSelector.value);
    }
});

// Admin Visual Seat Matrix Loader
function loadSeatMatrix(shiftId) {
    const gridContainer = document.getElementById('seatGridContainer');
    if (!gridContainer) return;

    gridContainer.innerHTML = '<div style="text-align:center; padding: 30px;"><i class="fas fa-spinner fa-spin fa-2x"></i><p style="margin-top:10px;">Loading hall layout...</p></div>';

    fetch(`api/seat_matrix.php?shift_id=${shiftId}`)
        .then(res => res.json())
        .then(data => {
            if (!data.success) {
                gridContainer.innerHTML = `<div class="alert alert-danger">${data.message}</div>`;
                return;
            }

            const seatsByRow = data.rows;
            let html = '<div class="seat-grid-hall">';

            for (const [rowLabel, seats] of Object.entries(seatsByRow)) {
                html += `
                    <div class="seat-row">
                        <div class="row-header">${rowLabel}</div>
                        <div class="row-desks">
                `;

                seats.forEach(seat => {
                    let statusClass = 'status-available';
                    let statusTitle = 'Available Desk';
                    let userTag = '';

                    if (seat.status === 'booked') {
                        statusClass = 'status-booked';
                        statusTitle = `Booked: ${seat.student_name} (${seat.student_phone})`;
                        userTag = `<div style="font-size:0.65rem; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:50px;">${seat.student_name.split(' ')[0]}</div>`;
                    } else if (seat.status === 'hold') {
                        statusClass = 'status-hold';
                        statusTitle = `On Hold: ${seat.student_name}`;
                        userTag = `<div style="font-size:0.65rem;">HOLD</div>`;
                    }

                    html += `
                        <div class="seat-box ${statusClass}" title="${statusTitle}" onclick="onSeatClicked(${seat.id}, '${seat.seat_number}', '${seat.status}', '${seat.student_name || ''}')">
                            <span class="seat-num">${seat.seat_number}</span>
                            ${userTag ? userTag : '<i class="fas fa-chair seat-icon"></i>'}
                        </div>
                    `;
                });

                html += `
                        </div>
                    </div>
                `;
            }

            html += '</div>';
            gridContainer.innerHTML = html;
        })
        .catch(err => {
            gridContainer.innerHTML = `<div class="alert alert-danger">Error loading seat grid: ${err.message}</div>`;
        });
}

function onSeatClicked(seatId, seatNumber, status, studentName) {
    if (typeof isAdmin !== 'undefined' && isAdmin) {
        if (status === 'available') {
            const seatSelect = document.getElementById('modalAllotSeatId');
            if (seatSelect) {
                seatSelect.value = seatId;
            }
            openModal('modalApproveAllot');
        } else {
            alert(`Desk ${seatNumber} is currently ${status.toUpperCase()}.\nOccupied by: ${studentName || 'N/A'}`);
        }
    }
}
