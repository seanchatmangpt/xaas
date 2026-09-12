defmodule Xaas.Coupling do
  @moduledoc """
  Real, new Ash domain for the formal proposal coupling engine ticket
  (`docs/jira/v26.9.11/formal-proposal-coupling-engine.md`). Did not exist
  before this pass. Holds `Xaas.Coupling.CouplingRun`, the admission path
  that wires proposal sets into `Xaas.Coupling.Engine`'s real box-constrained
  weighted-least-squares solver.
  """
  use Ash.Domain,
    otp_app: :xaas,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Xaas.Coupling.CouplingRun)
  end
end
