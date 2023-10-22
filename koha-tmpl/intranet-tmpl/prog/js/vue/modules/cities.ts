import { createApp } from "vue";
import { createWebHistory, createRouter } from "vue-router";
import { createPinia } from "pinia";

import { library } from "@fortawesome/fontawesome-svg-core";
import {
    faPlus,
    faMinus,
    faPencil,
    faTrash,
    faSpinner,
} from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/vue-fontawesome";
import vSelect from "vue-select";

library.add(faPlus, faMinus, faPencil, faTrash, faSpinner);

import App from "../components/Cities/Main.vue";

import { routes } from "../routes/cities";

const router = createRouter({
    history: createWebHistory(),
    linkActiveClass: "current",
    routes,
});

import { useMainStore } from "../stores/main";

const pinia = createPinia();

const i18n = {
    install: app => {
        app.config.globalProperties.$__ = key => {
            return window["__"](key);
        };
    },
};

const admin_menu_template = document.getElementById("admin-menu-template");
const app = createApp(App, {
    admin_menu_content: admin_menu_template?.innerHTML ?? "",
})
    .use(i18n)
    .use(pinia)
    .use(router)
    .component("font-awesome-icon", FontAwesomeIcon)
    .component("v-select", vSelect);

app.config.unwrapInjectedRef = true;

const mainStore = useMainStore(pinia);
app.provide("mainStore", mainStore);

app.mount("#cities");
