<template>
    <div>
        <div id="sub-header">
            <Breadcrumbs />
            <Help />
        </div>
        <div class="main container-fluid">
            <div class="row">
                <div class="col-sm-10 col-sm-push-2">
                    <main>
                        <Dialog />
                        <router-view />
                    </main>
                </div>
                <div class="col-sm-2 col-sm-pull-10">
                    <aside v-html="admin_menu_content"></aside>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import { inject, ref } from "vue"
import Breadcrumbs from "../Breadcrumbs.vue"
import Help from "../Help.vue"
import Dialog from "../Dialog.vue"
import { APIClient } from "../../fetch/api-client.js"
import "vue-select/dist/vue-select.css"
import { storeToRefs } from "pinia"

export default {
    setup() {
        const mainStore = inject("mainStore")
        const { loading, loaded, setError } = mainStore

        return {
            setError,
            loading,
            loaded,
        }
    },
    props: {
        admin_menu_content: {
            type: String,
        },
    },
    components: {
        Breadcrumbs,
        Dialog,
        Help,
    },
}
</script>

<style>
#menu ul ul,
#navmenulist ul ul {
    padding-left: 2em;
    font-size: 100%;
}

form .v-select {
    display: inline-block;
    background-color: white;
    width: 30%;
}

.v-select,
input:not([type="submit"]):not([type="search"]):not([type="button"]):not([type="checkbox"]):not([type="radio"]),
textarea {
    border-color: rgba(60, 60, 60, 0.26);
    border-width: 1px;
    border-radius: 4px;
    min-width: 30%;
}

.flatpickr-input {
    width: 30%;
}

#navmenulist ul li a.current.disabled {
    background-color: inherit;
    border-left: 5px solid #e6e6e6;
    color: #000;
}

#navmenulist ul li a.disabled {
    color: #666;
    pointer-events: none;
    font-weight: 700;
}
</style>
