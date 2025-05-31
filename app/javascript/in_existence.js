let isBulk = false; // set by the tab

function validateEmail() {
  const emailInput = document.getElementById("emailInput");
  const email = emailInput.value.trim();
  emailInput.style.color = ""

  if (!email) {
    document.getElementById("result").innerText = "Please enter an email.";
    return;
  }

  const formData = new FormData();
  formData.append("file", new Blob([email], { type: "text/plain" }), "email.txt");

  document.getElementById("result").innerText = `⏳ Validating...`;
  postEmailFile(formData);
  //emailInput.value = "";
}

function postEmailFile(formData) {
  const emailInput = document.getElementById("emailInput");

  fetch("/validate", {
    method: "POST",
    body: formData,
  })
    .then((response) => response.json())
    .then((data) => {
      const resultEl = document.getElementById("result");
      if (data.error) {
        resultEl.innerText = "Error: " + data.error;
        if (emailInput) emailInput.style.color = "red";
        return;
      }

      const downloadUrl = data.message;

      fetch(downloadUrl, { method: 'HEAD' })
        .then((res) => {
          if (res.ok) {
            if (isBulk) {
              resultEl.innerText = "✅ Success! Downloading results...";
              const a = document.createElement("a");
              a.href = downloadUrl;
              a.download = "";
              document.body.appendChild(a);
              a.click();
              document.body.removeChild(a);
            } else {
              resultEl.innerText = "✅ Email validated!";
              if (emailInput) emailInput.style.color = "#1DB954"; // green
            }
          } else {
            if (isBulk) {
              resultEl.innerText = "❌ There are no valid emails in this list.";
            } else {
              resultEl.innerText = "❌ Email not validated.";
              if (emailInput) emailInput.style.color = "red";
            }
          }
        })
        .catch(() => {
          resultEl.innerText = "⚠️ Could not check validation result.";
          if (!isBulk && emailInput) emailInput.style.color = "red";
        });
    }); 
}


// ---------- LIST FILE ----------

document.addEventListener("DOMContentLoaded", () => {
  const dropZone = document.getElementById("dropZone");

  dropZone.addEventListener("dragover", (event) => {
    event.preventDefault();
    dropZone.classList.add("hover");
  });

  dropZone.addEventListener("dragleave", () => {
    dropZone.classList.remove("hover");
  });

  dropZone.addEventListener("drop", (event) => {
    event.preventDefault();
    dropZone.classList.remove("hover");

    const file = event.dataTransfer.files[0];

    if (file && (file.type === "text/plain" || file.name.endsWith(".csv"))) {
      handleFileUpload(file);
    } else {
      document.getElementById("result").innerText = "Please upload a valid .txt or .csv file.";
    }
  });
});

function handleFileUpload(file) {
  const reader = new FileReader();
  reader.onload = function (event) {
    const emailList = event.target.result.split("\n");

    document.getElementById("result").innerText = `File loaded with ${emailList.length} emails. ⏳ Validating...`;

    // Optional: remove delay if not needed
    setTimeout(() => {
      sendEmailListForValidation(emailList);
    }, 3000);
  };
  reader.readAsText(file);
}

function checkEnter(event) {
  if (event.key === "Enter") {
    validateEmail();
  }
}

function sendEmailListForValidation(emailList) {
  const formData = new FormData();
  formData.append("file", new Blob([emailList.join("\n")], { type: "text/plain" }), "emails.txt");

  postEmailFile(formData);
}

// --------- TAB ---------------

function showTab(mode) {
  const single = document.getElementById("singleMode");
  const multiple = document.getElementById("multipleMode");
  const tabSingle = document.getElementById("tabSingle");
  const tabMultiple = document.getElementById("tabMultiple");

  if (mode === 'single') {
    isBulk = false;
    single.style.display = 'flex';
    multiple.style.display = 'none';
    tabSingle.classList.add('active');
    tabMultiple.classList.remove('active');
  } else {
    isBulk = true;
    single.style.display = 'none';
    multiple.style.display = 'block';
    tabMultiple.classList.add('active');
    tabSingle.classList.remove('active');
  }
}