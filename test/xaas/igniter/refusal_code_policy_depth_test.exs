defmodule Xaas.Igniter.RefusalCodePolicyDepthTest do
  @moduledoc """
  Lane W984ak — depth batch 3, family 3: `Xaas.Igniter.RefusalCode`
  (private ETS projection of ggen_igniter's typed refusal vocabulary).

  Uncovered slice (read-first: `test/xaas/igniter/igniter_catalog_test.exs`
  courts the Catalog ingest path against the REAL schema;
  `test/xaas/igniter_deepening_test.exs` courts RefusalCode only at a
  create/read round-trip and the open-vocabulary typing pin): the
  resource's own policy/identity/update invariants —

    * `code` is the writable string primary key: a row is addressable by
      its code and re-creating the same code is a typed Invalid refusal,
    * the W982u deny-by-default policy floor: authorized create/update/
      destroy refuse `Ash.Error.Forbidden` while the `authorize?: false`
      internal path keeps working and reads stay open,
    * the `:update` accept-list contract: `family`/`retryable`/
      `broken_term`/`owner`/`fix_hint` are mutable, `code` (the identity)
      is not rewritable through update input,
    * attribute defaults: `retryable` defaults to false; a legacy-form
      code string (e.g. `REFUSED_SOME_CODE`) is stored verbatim — the
      resource layer is honest open vocabulary (the pin already courted),
      asserted here at the storage level.

  Chicago-style: real Ash actions on the real private ETS store, no mocks.
  """

  use ExUnit.Case, async: false


  alias Xaas.Igniter.RefusalCode

  setup do
    RefusalCode |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    :ok
  end

  @code_attrs %{
    code: "REFUSED:W984AK_TEST_CODE",
    family: "depth-court",
    broken_term: "test broken term",
    owner: "w984ak",
    fix_hint: "fix by testing"
  }

  test "code is the writable primary key: the row is addressable by its code" do
    created = Ash.create!(RefusalCode, @code_attrs, action: :create, authorize?: false)

    fetched = Ash.get!(RefusalCode, @code_attrs.code, authorize?: false)
    assert fetched.code == created.code
    assert fetched.family == "depth-court"
    assert fetched.broken_term == "test broken term"
    assert fetched.owner == "w984ak"
    assert fetched.fix_hint == "fix by testing"

    # a legacy-form code string is stored verbatim (resource-level open
    # vocabulary) and a non-default retryable persists
    legacy =
      Ash.create!(
        RefusalCode,
        Map.merge(@code_attrs, %{code: "REFUSED_W984AK_LEGACY_FORM", retryable: true}),
        action: :create,
        authorize?: false
      )

    assert legacy.code == "REFUSED_W984AK_LEGACY_FORM"
    assert legacy.retryable
  end

  test "duplicate code create is refused typed; the original row survives unchanged" do
    original = Ash.create!(RefusalCode, @code_attrs, action: :create, authorize?: false)

    dup_cs =
      Ash.Changeset.for_create(
        RefusalCode,
        :create,
        Map.merge(@code_attrs, %{family: "other-family"})
      )

    assert {:error, %Ash.Error.Invalid{}} = Ash.create(dup_cs, authorize?: false)

    [only] = Ash.read!(RefusalCode, authorize?: false)
    assert only.code == original.code
    assert only.family == "depth-court"
  end

  test "policy floor: authorized create refuses Forbidden and writes nothing; the internal path admits" do
    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.create(RefusalCode, @code_attrs, action: :create, authorize?: true)

    assert [] = Ash.read!(RefusalCode, authorize?: false)

    assert %RefusalCode{} =
             Ash.create!(RefusalCode, @code_attrs, action: :create, authorize?: false)

    assert [%RefusalCode{}] = Ash.read!(RefusalCode, authorize?: false)
  end

  test "policy floor: authorized update and destroy refuse Forbidden; rows survive" do
    code = Ash.create!(RefusalCode, @code_attrs, action: :create, authorize?: false)

    assert {:error, %Ash.Error.Forbidden{}} =
             code
             |> Ash.Changeset.for_update(:update, %{retryable: true})
             |> Ash.update(authorize?: true)

    assert {:error, %Ash.Error.Forbidden{}} = Ash.destroy(code, authorize?: true)

    reloaded = Ash.get!(RefusalCode, code.code, authorize?: false)
    refute reloaded.retryable
    # the row survived both refused attempts
    assert [%RefusalCode{}] = Ash.read!(RefusalCode, authorize?: false)
  end

  test "update mutates the accepted fields and never the code identity; retryable defaults false" do
    code = Ash.create!(RefusalCode, @code_attrs, action: :create, authorize?: false)
    refute code.retryable

    updated =
      code
      |> Ash.Changeset.for_update(:update, %{
        family: "depth-court-v2",
        retryable: true,
        broken_term: nil,
        fix_hint: "new hint"
      })
      |> Ash.update!(authorize?: false)

    assert updated.family == "depth-court-v2"
    assert updated.retryable
    assert is_nil(updated.broken_term)
    assert updated.fix_hint == "new hint"
    assert updated.code == @code_attrs.code
    assert updated.owner == "w984ak"

    reloaded = Ash.get!(RefusalCode, @code_attrs.code, authorize?: false)
    assert reloaded.code == @code_attrs.code
  end
end
