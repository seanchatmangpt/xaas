defmodule Xaas.Ocel do
  @moduledoc """
  Object-Centric Event Log (OCEL) domain -- ticket
  docs/jira/v26.9.11/object-centric-event-projection.md.

  Replaces case-oriented workflow execution's single artificial case id
  with an OCEL-shaped model: typed events relate to a *set* of typed
  objects (`Xaas.Ocel.Event`, `Xaas.Ocel.Object`, `Xaas.Ocel.EventObject`),
  objects relate to other objects (`Xaas.Ocel.ObjectObject`), and object
  state is a real, append-only fold of deltas
  (`Xaas.Ocel.ObjectStateDelta`), never a mutated column. `case_view =
  projection(events, objects)` is derived on demand by
  `Xaas.Ocel.CaseView`, never a persisted resource, per the ticket's
  case-view-derivation invariant.

  See `Xaas.Ocel.AshIdentity` (Ash-resource identity mapping),
  `Xaas.Ocel.Projection` (OCEL JSON projection + import), and each
  resource's own moduledoc for what is a real, admitted slice versus
  explicit `UNSUPPORTED`.
  """

  use Ash.Domain,
    otp_app: :xaas,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Xaas.Ocel.Object)
    resource(Xaas.Ocel.Event)
    resource(Xaas.Ocel.EventObject)
    resource(Xaas.Ocel.ObjectObject)
    resource(Xaas.Ocel.ObjectStateDelta)
  end
end
