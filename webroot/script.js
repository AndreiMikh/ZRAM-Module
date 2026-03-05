let refreshing = false;
let lastData = {
  algorithm: "Unknown",
  size: "Unknown",
  used: "Unknown",
  ratio: "Unknown"
};
let fetchFailCount = 0; // Count of Consecutive Failures

async function refreshZram() {
  if (refreshing) return;
  refreshing = true;

  try {
    const res = await fetch("tmp/status.json?ts=" + Date.now());
    if (!res.ok) throw new Error("The Status File does Not Exist or the Server is Wrong");
    const json = await res.json();

    // If the Data is Abnormal/Missing, it is also Considered a Failure
    if (!json || !json.algorithm || !json.size || !json.used || !json.ratio) throw new Error("状态数据不完整");

    // Display Data and Clear Error Messages
    setStatus(json.algorithm, autoUnit(json.size), autoUnit(json.used), json.ratio, false, "");
    lastData = {
      algorithm: json.algorithm,
      size: autoUnit(json.size),
      used: autoUnit(json.used),
      ratio: json.ratio
    };
    fetchFailCount = 0;
  } catch (e) {
    fetchFailCount++;
    // Only on the First Load is it All Set as an Error
    if (fetchFailCount === 1 && !lastData.hasOwnProperty("loadedOnce")) {
      setStatus("Wrong", "Wrong", "Wrong", "Wrong", false, "Unable to Obtain Status：" + e.message);
    } else if (fetchFailCount >= 3) {
      // 3 Consecutive Failures are All Mistakes
      setStatus("Wrong", "Wrong", "Wrong", "Wrong", false, "The Status Cannot be Read Multiple Times in a Row：" + e.message);
    } else {
      // Existing Data is Maintained when it Fails, and Only the Small Red Tip at the Top is Displayed
      setStatus(lastData.algorithm, lastData.size, lastData.used, lastData.ratio, false, "The Read State Failed (Network or Write Delay) and was Automatically Retried…");
    }
  }
  lastData.loadedOnce = true;
  refreshing = false;
}

function autoUnit(str) {
  if (!str) return "";
  let n = parseInt(str, 10);
  if (isNaN(n)) return str;
  if (n > 1024 * 1024) return (n / 1024 / 1024).toFixed(2) + " GB";
  if (n > 1024) return (n / 1024).toFixed(2) + " MB";
  return n + " KB";
}

function setStatus(algo, size, used, ratio, skeleton, tip) {
  ["algo", "size", "used", "ratio"].forEach((id, i) => {
    const el = document.getElementById(id);
    el.classList.remove("skeleton");
    if (skeleton) el.classList.add("skeleton");
    if ([algo, size, used, ratio][i] !== null)
      el.innerText = [algo, size, used, ratio][i];
  });
  // Error Prompt
  let tipEl = document.getElementById("errtip");
  if (!tipEl) {
    tipEl = document.createElement("div");
    tipEl.id = "errtip";
    tipEl.style = "color:#d00;text-align:center;margin-top:8px;";
    document.getElementById("zram-status").appendChild(tipEl);
  }
  tipEl.innerText = tip || "";
}

window.addEventListener("DOMContentLoaded", () => {
  // The Skeleton Screen is Displayed at the Beginning
  setStatus("Loading...", "Loading...", "Loading...", "Loading...", true, "");
  refreshZram();
  setInterval(refreshZram, 1000);
  document.getElementById("refresh-btn")?.addEventListener("click", (e) => {
    if (refreshing) e.preventDefault();
    else refreshZram();
  });
});
