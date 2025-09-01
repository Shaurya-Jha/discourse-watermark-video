import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";

export default {
  name: "watermark-upload",

  initialize() {
    withPluginApi("1.8.0", (api) => {
      // Add a button in the composer toolbar
      api.addComposerToolbarButton({
        id: "upload-watermark",
        group: "extras", // shows on the right side
        icon: "image", // Discourse has FontAwesome icons
        title: "Upload Watermark",
        action: (toolbarEvent) => {
          // Create a hidden file input
          let input = document.createElement("input");
          input.type = "file";
          input.accept = "image/*";

          input.onchange = () => {
            let file = input.files[0];
            if (!file) return;

            let data = new FormData();
            data.append("file", file);

            ajax("/watermark/upload", {
              type: "POST",
              data,
              processData: false,
              contentType: false,
            }).then((response) => {
              // Insert a markdown link to the uploaded image into the composer
              toolbarEvent.addText(`![watermark](${response.url})`);
            }).catch((err) => {
              console.error("Upload failed:", err);
              alert("Failed to upload watermark image");
            });
          };

          input.click();
        },
      });
    });
  },
};
