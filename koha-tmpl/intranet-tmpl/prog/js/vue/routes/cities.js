import Home from "../components/Cities/Home.vue";

const breadcrumbs = {
    home: {
        text: "Home", // $t("Home")
        path: "/cgi-bin/koha/mainpage.pl",
    },
    admin_home: {
        text: "Administration", // $t("Administration")
        path: "/cgi-bin/koha/admin/admin-home.pl",
    },
    cities: {
        text: "Cities", // $t("Cities")
        path: "/cgi-bin/koha/admin/cities.pl",
    },
};

export const routes = [
    {
        path: "/cgi-bin/koha/mainpage.pl",
        beforeEnter() {
            window.location.href = "/cgi-bin/koha/mainpage.pl";
        },
    },
    {
        path: "/cgi-bin/koha/admin/admin-home.pl",
        beforeEnter() {
            window.location.href = "/cgi-bin/koha/admin/admin-home.pl";
        },
    },
    {
        path: "/cgi-bin/koha/admin/cities.pl",
        name: "Home",
        component: Home,
        meta: {
            breadcrumb: () => [
                breadcrumbs.home,
                breadcrumbs.admin_home,
                breadcrumbs.cities,
            ],
        },
    },
];
