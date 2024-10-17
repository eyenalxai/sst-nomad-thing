/// <reference path="./.sst/platform/config.d.ts" />

import { readFileSync } from "node:fs"

const getEnvVariables = () => {
	const nomadUrl = process.env.NOMAD_URL
	if (!nomadUrl) throw new Error("NOMAD_URL is not set")

	const nomadToken = process.env.NOMAD_TOKEN
	if (!nomadToken) throw new Error("NOMAD_TOKEN is not set")

	const domain = process.env.DOMAIN
	if (!domain) throw new Error("DOMAIN is not set")

	const postgresPassword = process.env.POSTGRES_PASSWORD
	if (!postgresPassword) throw new Error("POSTGRES_PASSWORD is not set")

	const postgresUser = process.env.POSTGRES_USER
	if (!postgresUser) throw new Error("POSTGRES_USER is not set")

	const postgresDatabase = process.env.POSTGRES_DB
	if (!postgresDatabase) throw new Error("POSTGRES_DB is not set")

	return {
		nomadUrl,
		nomadToken,
		domain,
		postgresPassword,
		postgresUser,
		postgresDatabase
	}
}

export default $config({
	app(input) {
		return {
			name: "sst-nomad-thing",
			removal: input?.stage === "production" ? "retain" : "remove",
			home: "local",
			providers: { nomad: "2.3.3" }
		}
	},
	async run() {
		const {
			nomadUrl,
			nomadToken,
			domain,
			postgresPassword,
			postgresUser,
			postgresDatabase
		} = getEnvVariables()

		const nomadProvider = new nomad.Provider("NomadProvider", {
			address: nomadUrl,
			skipVerify: false,
			secretId: nomadToken
		})

		const traefik = new nomad.Job(
			"Traefik",
			{
				jobspec: readFileSync(".nomad/traefik.nomad", "utf-8"),
				hcl2: {
					vars: {
						NOMAD_URL: nomadUrl
					}
				}
			},
			{
				provider: nomadProvider
			}
		)

		const echo = new nomad.Job(
			"Echo",
			{
				jobspec: readFileSync(".nomad/echo.nomad", "utf-8"),
				hcl2: {
					vars: {
						POSTGRES_PASSWORD: postgresPassword,
						POSTGRES_USER: postgresUser,
						POSTGRES_DATABASE: postgresDatabase,
						DOMAIN: domain
					}
				}
			},
			{
				provider: nomadProvider
			}
		)

		const postgres = new nomad.Job(
			"Postgres",
			{
				jobspec: readFileSync(".nomad/postgres.nomad", "utf-8"),
				hcl2: {
					vars: {
						POSTGRES_PASSWORD: postgresPassword,
						POSTGRES_USER: postgresUser,
						POSTGRES_DATABASE: postgresDatabase,
						DOMAIN: domain
					}
				}
			},
			{
				provider: nomadProvider
			}
		)
	}
})
