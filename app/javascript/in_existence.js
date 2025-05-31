function validateEmail() {
  const emailInput = document.getElementById("emailInput");
  const email = emailInput.value.trim();

  if (!email) {
    document.getElementById("result").innerText = "Please enter an email.";
    return;
  }

  const formData = new FormData();
  formData.append("file", new Blob([email], { type: "text/plain" }), "email.txt");

  postEmailFile(formData);
  emailInput.value = "";
}

function postEmailFile(formData) {
  fetch("/validate", {
    method: "POST",
    body: formData,
  })
    .then((response) => response.json())
    .then((data) => {
      const resultEl = document.getElementById("result");
      if (data.error) {
        resultEl.innerText = "Error: " + data.error;
      } else {
        resultEl.innerText = "✅ Success! Downloading results...";

        const downloadUrl = data.message;

        // Automatically trigger the download
        const a = document.createElement("a");
        a.href = downloadUrl;
        a.download = ""; // Let the server-sent filename be used
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      }
    })
    .catch((error) => {
      document.getElementById("result").innerText = "Something went wrong.";
      console.error(error);
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