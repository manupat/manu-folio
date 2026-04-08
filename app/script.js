/* ──────── Particle canvas ──────── */
const canvas = document.getElementById('particle-canvas');
const ctx = canvas.getContext('2d');
let particles = [];
let animId;

function resize() {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
}
resize();
window.addEventListener('resize', () => { resize(); initParticles(); });

function initParticles() {
  particles = [];
  const count = Math.min(Math.floor((canvas.width * canvas.height) / 14000), 90);
  for (let i = 0; i < count; i++) {
    particles.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      r: Math.random() * 1.5 + 0.3,
      vx: (Math.random() - 0.5) * 0.35,
      vy: (Math.random() - 0.5) * 0.35,
      alpha: Math.random() * 0.5 + 0.1,
    });
  }
}
initParticles();

function drawParticles() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  for (const p of particles) {
    p.x += p.vx; p.y += p.vy;
    if (p.x < 0) p.x = canvas.width;
    if (p.x > canvas.width) p.x = 0;
    if (p.y < 0) p.y = canvas.height;
    if (p.y > canvas.height) p.y = 0;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(108,99,255,${p.alpha})`;
    ctx.fill();
  }
  // Draw connecting lines
  for (let i = 0; i < particles.length; i++) {
    for (let j = i + 1; j < particles.length; j++) {
      const dx = particles[i].x - particles[j].x;
      const dy = particles[i].y - particles[j].y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist < 120) {
        ctx.beginPath();
        ctx.strokeStyle = `rgba(108,99,255,${0.06 * (1 - dist / 120)})`;
        ctx.lineWidth = 0.5;
        ctx.moveTo(particles[i].x, particles[i].y);
        ctx.lineTo(particles[j].x, particles[j].y);
        ctx.stroke();
      }
    }
  }
  animId = requestAnimationFrame(drawParticles);
}
drawParticles();

/* ──────── Typed effect ──────── */
const typedEl = document.getElementById('typed');
const roles = ['Cloud Architect', 'AI Engineer', 'DevOps Engineer', 'Solution Architect', 'Full Stack Developer'];
let roleIdx = 0, charIdx = 0, deleting = false;

function typeLoop() {
  const current = roles[roleIdx];
  if (!deleting) {
    typedEl.textContent = current.slice(0, charIdx + 1);
    charIdx++;
    if (charIdx === current.length) {
      deleting = true;
      setTimeout(typeLoop, 1800);
      return;
    }
  } else {
    typedEl.textContent = current.slice(0, charIdx - 1);
    charIdx--;
    if (charIdx === 0) {
      deleting = false;
      roleIdx = (roleIdx + 1) % roles.length;
    }
  }
  setTimeout(typeLoop, deleting ? 50 : 80);
}
typeLoop();

/* ──────── Navbar scroll ──────── */
const navbar = document.getElementById('navbar');
window.addEventListener('scroll', () => {
  navbar.classList.toggle('scrolled', window.scrollY > 50);
});

/* ──────── Hamburger ──────── */
document.getElementById('hamburger').addEventListener('click', () => {
  navbar.classList.toggle('open');
});
document.querySelectorAll('.nav-links a').forEach(a => {
  a.addEventListener('click', () => navbar.classList.remove('open'));
});

/* ──────── Intersection Observer (fade-in) ──────── */
const fadeEls = document.querySelectorAll('.fade-in');
const io = new IntersectionObserver((entries) => {
  entries.forEach((e, i) => {
    if (e.isIntersecting) {
      // Stagger within same parent
      const siblings = e.target.parentElement.querySelectorAll('.fade-in');
      let delay = 0;
      siblings.forEach((s, idx) => { if (s === e.target) delay = idx * 100; });
      setTimeout(() => e.target.classList.add('visible'), delay);
      io.unobserve(e.target);
    }
  });
}, { threshold: 0.12 });
fadeEls.forEach(el => io.observe(el));

/* ──────── Animated counters ──────── */
const statNumbers = document.querySelectorAll('.stat-number');
const counterIO = new IntersectionObserver((entries) => {
  entries.forEach(e => {
    if (e.isIntersecting) {
      const el = e.target;
      const target = parseInt(el.dataset.target, 10);
      let start = 0;
      const duration = 1200;
      const step = (timestamp) => {
        if (!start) start = timestamp;
        const progress = Math.min((timestamp - start) / duration, 1);
        el.textContent = Math.floor(progress * target);
        if (progress < 1) requestAnimationFrame(step);
        else el.textContent = target;
      };
      requestAnimationFrame(step);
      counterIO.unobserve(el);
    }
  });
}, { threshold: 0.5 });
statNumbers.forEach(el => counterIO.observe(el));

/* ──────── Active timeline item on hover ──────── */
document.querySelectorAll('.timeline-item').forEach(item => {
  item.addEventListener('mouseenter', () => {
    document.querySelectorAll('.timeline-item').forEach(i => i.classList.remove('active'));
    item.classList.add('active');
  });
});
