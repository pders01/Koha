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

    // Handle zip/image file type selection
    const zipfileRadio = document.getElementById("zipfile");
    const imageRadio = document.getElementById("image");
    const biblionumberEntry = document.getElementById("biblionumber_entry");

    if (zipfileRadio) {
        zipfileRadio.addEventListener("click", function () {
            if (biblionumberEntry) biblionumberEntry.style.display = "none";
        });
    }

    if (imageRadio) {
        imageRadio.addEventListener("click", function () {
            if (biblionumberEntry) biblionumberEntry.style.display = "block";
        });
    }

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

    // Handle cancel/save image buttons
    const filedragElement = document.getElementById("filedrag");
    if (filedragElement) {
        filedragElement.addEventListener("click", function (e) {
            if (e.target.classList.contains("cancel_image")) {
                e.preventDefault();
                document.getElementById("click_to_select").style.display =
                    "block";
                document.getElementById("messages").innerHTML = "";
                document.getElementById("fileToUpload").disabled = false;
                document.getElementById("process_images").style.display =
                    "none";
                document.getElementById("fileuploadstatus").style.display =
                    "none";
                return false;
            }
            if (e.target.classList.contains("save_image")) {
                e.preventDefault();
                document.getElementById("processfile").submit();
            }
        });
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
    document.getElementById("upload_results").style.display = "none";

    if (!validateFile(file)) {
        resetForm();
        return;
    }

    displayFileInfo(file);
    uploadFileToAPI();
}

function validateFile(file) {
    if (file.type.indexOf("image") === 0) {
        if (!file.type.match(/^image\/(gif|jpeg|jpg|png|xpm)$/i)) {
            showError(
                __(
                    "Error: This tool only accepts GIF, JPEG, PNG, or XPM images."
                )
            );
            return false;
        }
        // Set form to image mode
        const imageRadio = document.getElementById("image");
        const zipRadio = document.getElementById("zipfile");
        const biblionumberEntry = document.getElementById("biblionumber_entry");

        if (imageRadio) {
            imageRadio.checked = true;
            if (biblionumberEntry) {
                biblionumberEntry.style.display = "block";
                const inputs =
                    biblionumberEntry.querySelectorAll("input, label");
                inputs.forEach(el => {
                    el.classList.add("required");
                    if (el.tagName === "INPUT") el.required = true;
                });
            }
        }
        if (zipRadio) zipRadio.checked = false;
    } else if (file.type.indexOf("zip") > 0 || file.name.endsWith(".zip")) {
        // Set form to zip mode
        const imageRadio = document.getElementById("image");
        const zipRadio = document.getElementById("zipfile");
        const biblionumberEntry = document.getElementById("biblionumber_entry");

        if (zipRadio) zipRadio.checked = true;
        if (imageRadio) imageRadio.checked = false;
        if (biblionumberEntry) biblionumberEntry.style.display = "none";
    } else {
        showError(
            __(
                "Error: This tool only accepts ZIP files or GIF, JPEG, PNG, or XPM images."
            )
        );
        return false;
    }
    return true;
}

function displayFileInfo(file) {
    let displayContent = "";

    if (file.type.indexOf("image") === 0) {
        const reader = new FileReader();
        reader.onload = function (e) {
            document.getElementById("messages").innerHTML =
                '<p><img class="cover_preview" src="' +
                e.target.result +
                '" /></p>' +
                getFileInfoHTML(file);
        };
        reader.readAsDataURL(file);
    } else if (file.type.indexOf("zip") > 0 || file.name.endsWith(".zip")) {
        document.getElementById("messages").innerHTML =
            '<p><i class="fa-solid fa-file-zipper" aria-hidden="true"></i></p>' +
            getFileInfoHTML(file);
    }
}

function getFileInfoHTML(file) {
    return (
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
        "</p>"
    );
}

function uploadFileToAPI() {
    document.getElementById("fileuploadstatus").style.display = "block";
    document.getElementById("upload_options").style.display = "block";

    const formData = new FormData();
    formData.append("file", selectedFile);
    formData.append("category", "cover_images");
    formData.append("public", "0");
    formData.append("temp", "1"); // Temporary upload until processed

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
            document.getElementById("uploadedfileid").value = uploadedFileId;
            document.getElementById("fileuploadprogress").value = 100;
            document.querySelector(".fileuploadpercent").textContent = "100";
            document.getElementById("fileToUpload").disabled = true;
            document.getElementById("process_images").style.display = "block";
        } else {
            const error = JSON.parse(xhr.responseText);
            handleUploadError(xhr.status, error);
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

function handleUploadError(status, error) {
    const errorMessages = [
        __("Error code 0 not used"),
        __("File already exists"),
        __("Directory is not writeable"),
        __("Root directory for uploads not defined"),
        __("Temporary directory for uploads not defined"),
    ];

    let errorMsg = __("Upload status: Failed");
    if (error.error_code === "duplicate_file") {
        errorMsg += " - " + __("File already exists");
    } else if (error.error) {
        errorMsg += " - " + error.error;
    }

    document.getElementById("fileuploadstatus").style.display = "none";
    document.getElementById("fileuploadfailed").style.display = "block";
    document.getElementById("fileuploadfailed").textContent = errorMsg;
    document.getElementById("processfile").style.display = "none";
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
                    "/cgi-bin/koha/tools/upload-cover-image.pl?biblionumber=" +
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
