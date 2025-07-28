/* global __ interface theme biblionumber itemnumber allowMultipleCovers uploadedFileId selectedFile APIClient */

// Global variables for upload management
let uploadedFileId = null;
let selectedFile = null;

document.addEventListener("DOMContentLoaded", function () {
    initializeUploadInterface();
});

function initializeUploadInterface() {
    // Prevent default browser behavior for file drops
    document.addEventListener("drop", function (e) {
        e.preventDefault();
        e.stopPropagation();
    });

    // Handle drag and drop events
    const fileDrag = document.getElementById("filedrag");
    if (fileDrag) {
        fileDrag.addEventListener("dragenter", handleDragEvent);
        fileDrag.addEventListener("dragover", handleDragEvent);
        fileDrag.addEventListener("dragleave", handleDragEvent);
        fileDrag.addEventListener("drop", handleFileDrop);
        fileDrag.addEventListener("click", function () {
            document.getElementById("fileToUpload").click();
        });
    }

    // Handle file input change
    const fileInput = document.getElementById("fileToUpload");
    if (fileInput) {
        fileInput.addEventListener("change", function () {
            if (this.files.length > 0) {
                handleFileSelection(this.files[0]);
            }
        });
    }

    // Handle process cover button
    const processBtn = document.getElementById("process_cover_btn");
    if (processBtn) {
        processBtn.addEventListener("click", processCoverImage);
    }

    // Handle existing image deletion
    const removeButtons = document.querySelectorAll(".thumbnails .remove");
    removeButtons.forEach(button => {
        button.addEventListener("click", function (e) {
            e.preventDefault();
            if (
                confirm(__("Are you sure you want to delete this cover image?"))
            ) {
                const imagenumber = this.dataset.coverimg;
                removeLocalImage(imagenumber);
            }
        });
    });

    // Initialize biblionumber field behavior
    if (!biblionumber && !itemnumber) {
        const biblioInput = document.getElementById("biblionumber_input");
        if (biblioInput) {
            biblioInput.addEventListener("input", function () {
                biblionumber = this.value;
            });
        }
    }
}

function handleDragEvent(e) {
    e.stopPropagation();
    e.preventDefault();
    e.target.className = e.type === "dragover" ? "hover" : "";
}

function handleFileDrop(e) {
    e.stopPropagation();
    e.preventDefault();
    const files = e.dataTransfer.files;
    if (files.length > 0) {
        handleFileSelection(files[0]);
    }
}

function handleFileSelection(file) {
    selectedFile = file;
    document.getElementById("click_to_select").style.display = "none";
    document.getElementById("messages").innerHTML = "";

    if (!validateFile(file)) {
        resetForm();
        return;
    }

    displayFileInfo(file);
    uploadFileToAPI();
}

function validateFile(file) {
    if (!file.type.match(/^image\/(gif|jpeg|jpg|png|xpm)$/i)) {
        showError(
            __("Error: This tool only accepts GIF, JPEG, PNG, or XPM images.")
        );
        return false;
    }
    return true;
}

function displayFileInfo(file) {
    if (file.type.indexOf("image") === 0) {
        const reader = new FileReader();
        reader.onload = function (e) {
            document.getElementById("messages").innerHTML =
                '<p><img class="cover_preview" src="' +
                e.target.result +
                '" /></p>' +
                "<p><strong>" +
                __("File name:") +
                "</strong> " +
                file.name +
                "<br />" +
                "<strong>" +
                __("File type:") +
                "</strong> " +
                file.type +
                "<br />" +
                "<strong>" +
                __("File size:") +
                "</strong> " +
                convertSize(file.size) +
                "</p>";
        };
        reader.readAsDataURL(file);
    }
}

function uploadFileToAPI() {
    document.getElementById("fileuploadstatus").style.display = "block";
    document.getElementById("upload_options").style.display = "block";

    const formData = new FormData();
    formData.append("file", selectedFile);
    formData.append("category", "cover_images");
    formData.append("public", "0");
    formData.append("temp", "1"); // Temporary upload until processed

    const client = APIClient.uploaded_files;

    // Custom upload with progress tracking
    const xhr = new XMLHttpRequest();

    xhr.upload.addEventListener("progress", function (e) {
        if (e.lengthComputable) {
            const percentComplete = Math.round((e.loaded / e.total) * 100);
            document.getElementById("fileuploadprogress").value =
                percentComplete;
            document.querySelector(".fileuploadpercent").textContent =
                percentComplete;
        }
    });

    xhr.onload = function () {
        if (xhr.status === 201) {
            const data = JSON.parse(xhr.responseText);
            uploadedFileId = data.file_id;
            document.getElementById("fileuploadprogress").value = 100;
            document.querySelector(".fileuploadpercent").textContent = "100";
            document.getElementById("fileToUpload").disabled = true;
            document.getElementById("process_images").style.display = "block";
        } else {
            const error = JSON.parse(xhr.responseText);
            showError(__("Upload failed: ") + error.error);
            resetForm();
        }
    };

    xhr.onerror = function () {
        showError(__("Upload failed: Network error"));
        resetForm();
    };

    xhr.open("POST", "/api/v1/uploaded_files");
    xhr.setRequestHeader(
        "CSRF-TOKEN",
        document
            .querySelector('meta[name="csrf-token"]')
            .getAttribute("content")
    );
    xhr.send(formData);
}

function processCoverImage() {
    if (!uploadedFileId) {
        showError(__("No file uploaded"));
        return;
    }

    const targetBiblionumber =
        biblionumber || document.getElementById("biblionumber_input")?.value;
    const targetItemnumber = itemnumber || null;
    const replace = document.getElementById("replace").checked;

    if (!targetBiblionumber && !targetItemnumber) {
        showError(__("Please specify a biblionumber"));
        return;
    }

    const processBtn = document.getElementById("process_cover_btn");
    processBtn.disabled = true;
    processBtn.textContent = __("Processing...");

    // Create a form to submit to the traditional cover processing endpoint
    const form = new FormData();
    form.append("uploadedfileid", uploadedFileId);
    form.append("op", "cud-process");
    form.append("filetype", "image");
    form.append("replace", replace ? "1" : "0");

    if (targetBiblionumber) {
        form.append("biblionumber", targetBiblionumber);
    }
    if (targetItemnumber) {
        form.append("itemnumber", targetItemnumber);
    }

    // Submit to the original CGI script for cover processing
    fetch("/cgi-bin/koha/tools/upload-cover-image.pl", {
        method: "POST",
        body: form,
        headers: {
            "CSRF-TOKEN": document
                .querySelector('meta[name="csrf-token"]')
                .getAttribute("content"),
        },
    })
        .then(response => {
            if (response.ok) {
                return response.text();
            }
            throw new Error("Cover processing failed");
        })
        .then(html => {
            // Check if the response indicates success by looking for error patterns
            if (html.includes("error") || html.includes("alert-warning")) {
                throw new Error("Cover processing failed - check file format");
            }
            showSuccess(__("Cover image uploaded successfully"));
            cleanupTempFile();
            // Refresh the page after a delay
            setTimeout(() => {
                window.location.reload();
            }, 2000);
        })
        .catch(error => {
            showError(__("Failed to process cover image: ") + error.message);
            processBtn.disabled = false;
            processBtn.textContent = __("Process cover image");
        });
}

function cleanupTempFile() {
    if (uploadedFileId) {
        const client = APIClient.uploaded_files;
        client.uploaded_files.delete(uploadedFileId).catch(() => {
            // Ignore cleanup errors
        });
        uploadedFileId = null;
    }
}

function showError(message) {
    const results = document.getElementById("upload_results");
    results.innerHTML =
        '<div class="upload-result upload-error">' + message + "</div>";
    results.style.display = "block";
}

function showSuccess(message) {
    const results = document.getElementById("upload_results");
    results.innerHTML =
        '<div class="upload-result upload-success">' + message + "</div>";
    results.style.display = "block";
}

function resetForm() {
    document.getElementById("uploadpanel").style.display = "none";
    document.getElementById("upload_options").style.display = "none";
    document.getElementById("process_images").style.display = "none";
    document.getElementById("click_to_select").style.display = "block";
    document.getElementById("messages").innerHTML = "";
    document.getElementById("fileToUpload").disabled = false;
    document.getElementById("fileToUpload").value = "";
    document.getElementById("fileuploadprogress").value = 0;
    document.querySelector(".fileuploadpercent").textContent = "0";
    selectedFile = null;
    uploadedFileId = null;
}

function convertSize(size) {
    const sizes = ["Bytes", "KB", "MB", "GB", "TB"];
    if (size === 0) return "0 Byte";
    const i = parseInt(Math.floor(Math.log(size) / Math.log(1024)));
    return Math.round(size / Math.pow(1024, i), 2) + " " + sizes[i];
}

function removeLocalImage(imagenumber) {
    const thumbnail = document.getElementById("imagenumber-" + imagenumber);
    const copy = thumbnail.innerHTML;
    thumbnail.querySelector("img").style.opacity = ".2";
    thumbnail.querySelector("a.remove").innerHTML =
        "<img style='display:inline-block' src='" +
        interface +
        "/" +
        theme +
        "/img/spinner-small.gif' alt='' />";

    const client = APIClient.cover_image;
    client.cover_images.delete(imagenumber).then(
        success => {
            if (success.deleted === 1) {
                location.href =
                    "/cgi-bin/koha/tools/upload-cover-image-rest.pl?biblionumber=" +
                    biblionumber;
            } else {
                thumbnail.innerHTML = copy;
                alert(__("An error occurred on deleting this image"));
            }
        },
        error => {
            thumbnail.innerHTML = copy;
            alert(__("An error occurred on deleting this image"));
            console.warn("Something wrong happened: " + error);
        }
    );
}
