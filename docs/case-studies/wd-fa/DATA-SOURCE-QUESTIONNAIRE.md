# Data Source Questionnaire

For each source, capture:

| Field | Question |
|---|---|
| system | What system owns the data? |
| owner | Who can authorize integration? |
| subject identity | Which stable identifiers exist? |
| data type | structured, text, image, plot, waveform, binary? |
| access | API, database, file, export, event stream? |
| ACL | user/group/role semantics? |
| freshness | event-driven, hourly, daily, manual? |
| history | how many years and schema versions? |
| provenance | can an extracted assertion link back to exact source/version? |
| deletion/retention | what obligations exist? |
| quality | known gaps or duplicate identifiers? |
| test fixture | can representative redacted data be supplied for development? |

A source is not "integrated" merely because its text can be embedded.
