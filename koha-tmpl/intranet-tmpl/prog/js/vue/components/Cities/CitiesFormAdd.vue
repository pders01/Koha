<template>
    <h2>{{ $__("New city") }}</h2>
    <div>
        <form @submit="onSubmit($event)">
            <fieldset class="rows">
                <ol>
                    <li>
                        <label for="city" class="required">{{ $__("City") }}:</label>
                        <input id="city" v-model="city.name" :placeholder="$__('City')" required />
                        <span class="required">{{ $__("Required") }}</span>
                    </li>
                    <li>
                        <label for="state" class="required">{{ $__("State") }}:</label>
                        <input id="state" v-model="city.state" :placeholder="$__('State')" />
                    </li>
                    <li>
                        <label for="zip_postal_code" class="required">{{ $__("ZIP/Postal Code") }}:</label>
                        <input id="zip_postal_code" v-model="city.zip_postal_code" :placeholder="$__('ZIP/Postal Code')"
                            required />
                        <span class="required">{{ $__("Required") }}</span>
                    </li>
                    <li>
                        <label for="country" class="required">{{ $__("Country") }}:</label>
                        <input id="country" v-model="city.country" :placeholder="$__('Country')" />
                    </li>
                </ol>
            </fieldset>
            <fieldset class="action">
                <ButtonSubmit />
                <router-link :to="{ name: 'CitiesList' }" role="button" class="cancel">{{ $__("Cancel") }}</router-link>
            </fieldset>
        </form>
    </div>
</template>

<script>
export default {
    setup() {

    },
    data() {
        return {
            city: {
                name: "",
                state: "",
                zip_postal_code: "",
                country: "",
            }
        }
    },
    methods: {
        checkForm(city) {
            let errors = []

            let agreement_licenses = agreement.agreement_licenses
            // Do not use al.license.name here! Its name is not the one linked with al.license_id
            // At this point al.license is meaningless, form/template only modified al.license_id
            const license_ids = agreement_licenses.map(al => al.license_id)
            const duplicate_license_ids = license_ids.filter(
                (id, i) => license_ids.indexOf(id) !== i
            )

            if (duplicate_license_ids.length) {
                errors.push(this.$__("A license is used several times"))
            }

            const related_agreement_ids = agreement.agreement_relationships.map(
                rs => rs.related_agreement_id
            )
            const duplicate_related_agreement_ids =
                related_agreement_ids.filter(
                    (id, i) => related_agreement_ids.indexOf(id) !== i
                )

            if (duplicate_related_agreement_ids.length) {
                errors.push(
                    this.$__(
                        "An agreement is used as relationship several times"
                    )
                )
            }

            if (
                agreement_licenses.filter(al => al.status == "controlling")
                    .length > 1
            ) {
                errors.push(this.$__("Only one controlling license is allowed"))
            }

            if (
                agreement_licenses.filter(al => al.status == "controlling")
                    .length > 1
            ) {
                errors.push(this.$__("Only one controlling license is allowed"))
            }

            let documents_with_uploaded_files = agreement.documents.filter(
                doc => typeof doc.file_content !== "undefined"
            )
            if (
                documents_with_uploaded_files.filter(
                    doc => atob(doc.file_content).length >= max_allowed_packet
                ).length >= 1
            ) {
                errors.push(
                    this.$__("File size exceeds maximum allowed: %s MB").format(
                        (max_allowed_packet / (1024 * 1024)).toFixed(2)
                    )
                )
            }
            agreement.user_roles.forEach((user, i) => {
                if (user.patron_str === "") {
                    errors.push(
                        this.$__("Agreement user %s is missing a user").format(
                            i + 1
                        )
                    )
                }
            })
            setWarning(errors.join("<br>"))
            return !errors.length
        },
        onSubmit(e) {
            e.preventDefault()

            //let agreement= Object.assign( {} ,this.agreement); // copy
            let agreement = JSON.parse(JSON.stringify(this.city)) // copy

            // if (!this.checkForm(agreement)) {
            //     return false
            // }

            const client = APIClient.cities
            if (agreement_id) {
                client.agreements.update(agreement, agreement_id).then(
                    success => {
                        setMessage(this.$__("Agreement updated"))
                        this.$router.push({ name: "AgreementsList" })
                    },
                    error => {}
                )
            } else {
                client.agreements.create(agreement).then(
                    success => {
                        setMessage(this.$__("Agreement created"))
                        this.$router.push({ name: "AgreementsList" })
                    },
                    error => {}
                )
            }
        },
    }
}


</script>