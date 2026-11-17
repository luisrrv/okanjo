# RFC 9457 problem details (ADR 0023). title is for developers, detail for users.
json.type "https://warikan.lrod.dev/api/problems/#{code}"
json.title code.to_s.humanize
json.status status
json.detail t("api.errors.#{code}")
json.code code
json.errors errors if errors
