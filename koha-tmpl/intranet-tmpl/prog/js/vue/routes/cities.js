import { markRaw } from "vue";

import CitiesList from "../components/Cities/CitiesList.vue";
import CitiesFormAdd from "../components/Cities/CitiesFormAdd.vue"

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
                name: "CitiesList",
                component: markRaw(CitiesList),
            },
            {
                path: "add",
                name: "CitiesFormAdd",
                component: markRaw(CitiesFormAdd),
                title: $__("Add city"),
            },

        ],
    },
];
