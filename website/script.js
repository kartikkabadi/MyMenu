document.getElementById("year").textContent = new Date().getFullYear();

for (const link of document.querySelectorAll('a[href^="#"]')) {
  link.addEventListener("click", () => {
    const target = document.querySelector(link.getAttribute("href"));
    target?.focus({ preventScroll: true });
  });
}
