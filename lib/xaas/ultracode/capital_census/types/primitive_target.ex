defmodule Xaas.Ultracode.CapitalCensus.Types.PrimitiveTarget do
  use Ash.Type.Enum,
    values: [
      :ontology,
      :marketplace_pack,
      :hddl,
      :fond,
      :ggen,
      :sa2a,
      :ocel_beam4pm,
      :resolver,
      :court,
      :otp_ash_reactor
    ]
end
