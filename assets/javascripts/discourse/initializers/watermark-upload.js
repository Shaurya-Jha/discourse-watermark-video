import bootbox from "bootbox";
import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "watermark-upload",

  initialize() {
    withPluginApi("1.8.0", (api) => {
      api.addComposerToolbarButton({
        id: "upload-watermark",
        group: "extras",
        icon: "image",
        title: "Upload Watermark",
        action: (toolbarEvent) => {
          let input = document.createElement("input");
          input.type = "file";
          input.accept = "image/*";

          input.onchange = () => {
            let file = input.files[0];
            if (!file) {
              return;
            }

            let data = new FormData();
            data.append("file", file);

            ajax("/watermark/upload", {
              type: "POST",
              data,
              processData: false,
              contentType: false,
            })
              .then((response) => {
                toolbarEvent.addText(`![watermark](${response.url})`);
              })
              .catch(() => {
                bootbox.alert("Failed to upload watermark image");
              });
          };

          input.click();
        },
      });
    });
  },
};
