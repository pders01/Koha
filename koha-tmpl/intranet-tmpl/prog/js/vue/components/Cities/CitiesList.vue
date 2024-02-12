<template>
    <div>
        <Toolbar>
            <ToolbarButton
                :to="{ name: 'CitiesFormAdd' }"
                icon="plus"
                :title="$__('New city')"
            />
        </Toolbar>
        <div v-if="cities_count > 0" class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @show="doShow"
                @edit="doEdit"
                @delete="doDelete"
                @select="doSelect"
            ></KohaTable>
        </div>
        <div v-else class="dialog message">
            {{ $__("There are no cities defined") }}
        </div>
    </div>
</template>

<script>
import { inject, ref } from "vue"
import KohaTable from "../KohaTable.vue"
import Toolbar from "../Toolbar.vue"
import ToolbarButton from "../ToolbarButton.vue"
import { APIClient } from "../../fetch/api-client.js"

export default {
    setup() {
        const mainStore = inject("mainStore")
        const { loading, loaded, setError } = mainStore

        const table = ref()
        const cities = ref([])
        const cities_count = ref(Number)

        return {
            cities,
            cities_count,
            setError,
            loading,
            loaded,
        }
    },
    data() {
        return {
            tableOptions: {
                columns: this.getTableColumns(),
            },
        }
    },
    beforeCreate() {
        const cities_client = APIClient.cities
        cities_client.cities.list().then(cities => {
            this.cities = cities
            this.cities_count = cities.length
        })
    },
    methods: {
        getTableColumns() {
            return []
        },
    },
    components: {
        KohaTable,
        Toolbar,
        ToolbarButton,
    }
}
</script>