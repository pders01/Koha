export class UploadedFilesAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/uploaded_files/",
        });
        this.publicHttpClient = new HttpClient({
            baseURL: "/api/v1/public/uploaded_files/",
        });
    }

    get uploaded_files() {
        return {
            get: id =>
                this.httpClient.get({
                    endpoint: id,
                }),
            getAll: params =>
                this.httpClient.getAll({
                    endpoint: "",
                    query: params,
                }),
            post: body =>
                this.httpClient.post({
                    endpoint: "",
                    body: body,
                }),
            put: (id, body) =>
                this.httpClient.put({
                    endpoint: id,
                    body: body,
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: id,
                }),
            download: id =>
                this.httpClient.get({
                    endpoint: `${id}/download`,
                }),
            downloadPublic: id =>
                this.publicHttpClient.get({
                    endpoint: `${id}/download`,
                }),
        };
    }
}

export default UploadedFilesAPIClient;
