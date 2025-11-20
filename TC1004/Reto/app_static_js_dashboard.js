// /opt/mqtt-dashboard/app/static/js/dashboard.js
document.addEventListener('DOMContentLoaded', function() {
  const sprite = document.getElementById('mario');
  const messages = document.getElementById('messages');
  const statusList = document.getElementById('status-list');
  // Simplified 16x16 sprite map ( . = transparent )
  const mario16 = [
    "................",
    ".......11.......",
    "......1221......",
    ".....122221.....",
    "....11222211....",
    "...1133333311...",
    "...1333333331...",
    "..113333333331..",
    "..1333333333331..",
    ".13344444443331.",
    ".13344444443331.",
    ".13344444443331.",
    ".1133333333311..",
    "..1.33333331....",
    "..1.3333331.....",
    "...111111......"
  ];
  // render sprite pixels
  for (let r=0;r<16;r++){
    for (let c=0;c<16;c++){
      const ch = mario16[r][c] || '.';
      const el = document.createElement('div');
      if (ch === '.') el.style.background = 'transparent';
      else if (ch === '1') el.style.background = '#000';
      else if (ch === '2') el.style.background = '#f94144';
      else if (ch === '3') el.style.background = '#577590';
      else if (ch === '4') el.style.background = '#f9c74f';
      sprite.appendChild(el);
    }
  }

  const socket = io();
  socket.on('connect', () => console.log('Socket connected'));
  socket.on('mqtt_message', (data) => {
    const li = document.createElement('li');
    li.textContent = `${new Date().toLocaleTimeString()} ${data.topic} ${JSON.stringify(data.payload).slice(0,120)}`;
    messages.insertBefore(li, messages.firstChild);
    if (data.topic.includes('/status')) {
      const st = document.createElement('li');
      st.textContent = `${data.payload.device_id || 'device'} → ${data.payload.status || JSON.stringify(data.payload).slice(0,20)}`;
      statusList.insertBefore(st, statusList.firstChild);
    }
  });
});