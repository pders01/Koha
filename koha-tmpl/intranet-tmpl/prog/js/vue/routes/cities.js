import { markRaw } from "vue";

import Main from "../components/Cities/Main.vue";

import { $__ } from "../i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/admin/cities.pl",
        is_default: true,
        is_base: true,
        title: $__("Cities"),
        children: [
            {
                path: "",
                name: "Home",
                component: markRaw(Main),
                is_navigation_item: false,
            },
        ],
    },
];
