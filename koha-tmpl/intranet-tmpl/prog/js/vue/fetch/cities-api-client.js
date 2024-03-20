import HttpClient from "./http-client";

export class CitiesAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/",
        });
    }

    get cities() {
        return {
            list: () =>
                this.getAll({
                    endpoint: "cities",
                }),
        };
    }
}

export default CitiesAPIClient;
