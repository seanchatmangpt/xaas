# e2e/seed-witness.exs — deterministic W55 witness seed (v26.10.6).
#
# Run via: PATH="$HOME/.asdf/shims:$PATH" MIX_ENV=dev mix run e2e/seed-witness.exs
#
# Same shape as e2e/witness.spec.cjs's beforeAll seed (W97 fixed version):
# two deterministic subjects, check-first idempotency, write-once
# `:record_verification`. Executed as a real file so the shell never mangles
# the Elixir source (the `mix run -e` + JSON.stringify path broke on literal
# "\n" escapes — the original W55 failure).
require Ash.Query

alias Xaas.Witness.CertifiedReceipt

payload_hash_hex = String.duplicate("ab", 32)
signature_hex = String.duplicate("cd", 32)
verifying_key_hex = String.duplicate("ef", 32)

seeds = [
  %{subject: "sha256:e2e-w55-verified", want_verified?: true},
  %{subject: "sha256:e2e-w55-unverified", want_verified?: false}
]

Enum.each(seeds, fn seed ->
  # Pin must be a simple variable: ^seed.subject is not valid Elixir.
  subject = seed.subject

  existing =
    CertifiedReceipt
    |> Ash.Query.filter(subject == ^subject)
    |> Ash.read!()
    |> List.first()

  receipt =
    existing ||
      Ash.create!(
        CertifiedReceipt,
        %{
          subject: seed.subject,
          payload_hash_hex: payload_hash_hex,
          algorithm: :es256,
          signature_hex: signature_hex,
          verifying_key_hex: verifying_key_hex
        },
        [action: :ingest]
      )

  if seed.want_verified? and not receipt.verified do
    Ash.update!(receipt, %{}, action: :record_verification)
  end
end)

IO.puts("W55_SEED_OK")
