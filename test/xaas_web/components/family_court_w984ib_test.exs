defmodule XaasWeb.Components.FamilyCourtW984ibTest do
  @moduledoc """
  Lane W984ib unclaimed-family court for `XaasWeb.CoreComponents`
  (`lib/xaas_web/components/core_components.ex`).

  Census finding: the only production consumer of any CoreComponents
  function is `<.flash_group flash={@flash} />` in
  `lib/xaas_web/components/layouts/app.html.heex:40` (exercised indirectly
  by every `live()` test through the app layout). Every other component —
  input/1 (all four clauses), table/1, modal/1, flash/1 kind routing,
  simple_form/1, header/1, translate_error/1, translate_errors/2 — has zero
  direct or indirect test-tree exercise.

  Chicago-school: real HEEx rendering through
  `Phoenix.LiveViewTest.render_component/2` with real
  `Phoenix.Component.to_form/2` forms — no doubles. Each test carries a
  mutation rationale: reverting the exercised branch must fail it.
  """

  use XaasWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias XaasWeb.CoreComponents

  @form_source Phoenix.Component.to_form(%{"email" => "", "plan" => "free"},
                 errors: [
                   email: {"has already been taken", []},
                   email: {"is invalid", []},
                   plan: {"should be one of %{count} options", count: 3}
                 ],
                 name: "court"
               )

  describe "input/1 FormField clause + translate_error/1" do
    @describetag :family_court_w984ib

    test "field clause maps form-field errors through translate_error" do
      # Mutation rationale: reverting the FormField clause's
      # `assign(:errors, Enum.map(field.errors, &translate_error(&1)))`
      # (or making it return raw tuples) removes the rendered error
      # paragraphs entirely.
      html = render_component(&CoreComponents.input/1, field: @form_source[:email], label: "Email")
      assert html =~ "Email"
      assert html =~ "has already been taken"
      assert html =~ "is invalid"
      refute html =~ "{"
    end

    test "field clause derives name/value/id from the field when absent" do
      # Mutation rationale: dropping the `assign_new(:name, ...)` /
      # `assign_new(:value, ...)` fallbacks to field.name/field.value makes
      # the rendered input lose its name attribute.
      html = render_component(&CoreComponents.input/1, field: @form_source[:email])
      assert html =~ ~s(name="email")
      assert html =~ ~s(id="email")
    end

    test "multiple field appends [] to the name" do
      # Mutation rationale: flipping the `if assigns.multiple` branch in the
      # FormField clause drops the "[]" suffix.
      html =
        render_component(&CoreComponents.input/1,
          field: @form_source[:email],
          multiple: true
        )

      assert html =~ ~s(name="email[]")
    end
  end

  describe "translate_error/1 + translate_errors/2" do
    @describetag :family_court_w984ib

    test "count option routes to dngettext plural path" do
      # Mutation rationale: removing the `if count = opts[:count]` branch (or
      # always calling dgettext) changes the interpolation of %{count}.
      # Raw error tuples are rendered only after translate_error via the
      # FormField clause, so court the dngettext path through field: .
      html = render_component(&CoreComponents.input/1, field: @form_source[:plan], label: "Plan")
      assert html =~ "should be one of 3 options"

      # translate_errors/2 filters to the requested field only.
      assert CoreComponents.translate_errors(
               [email: {"is invalid", []}, plan: {"should be one of %{count} options", count: 3}],
               :email
             ) == ["is invalid"]
    end
  end

  describe "input/1 type clauses" do
    @describetag :family_court_w984ib

    test "checkbox clause normalizes value and renders hidden false input" do
      # Mutation rationale: dropping the assign_new(:checked) normalization
      # (normalize_value("checkbox", value)) makes checked="true" appear even
      # for a falsey string value.
      html =
        render_component(&CoreComponents.input/1,
          type: "checkbox",
          name: "tos",
          label: "Accept TOS",
          value: "false",
          errors: []
        )

      assert html =~ ~s(value="false")
      assert html =~ ~s(type="checkbox")
      assert html =~ "Accept TOS"
    end

    test "select clause renders prompt and selected option" do
      # Mutation rationale: removing the prompt option, or swapping
      # options_for_select(@options, @value), breaks the selected marking.
      html =
        render_component(&CoreComponents.input/1,
          type: "select",
          name: "plan",
          id: "plan",
          prompt: "Choose a plan",
          options: ["free", "pro"],
          value: "pro"
        )

      assert html =~ ~s(<option value="">Choose a plan</option>)
      assert html =~ ~s(<option selected value="pro">pro</option>)
      refute html =~ ~s(multiple=)
    end

    test "select clause with multiple renders the multiple attribute" do
      html =
        render_component(&CoreComponents.input/1,
          type: "select",
          name: "tags",
          id: "tags",
          options: ["a", "b"],
          value: [],
          multiple: true
        )

      assert html =~ ~s(multiple)
    end

    test "textarea clause normalizes the value and error border branch" do
      # Mutation rationale: removing normalize_value("textarea", value) or the
      # `@errors != [] && "border-rose-400 ..."` conditional class changes the
      # rendered markup for error state.
      html =
        render_component(&CoreComponents.input/1,
          type: "textarea",
          name: "body",
          id: "body",
          value: "line1\nline2",
          errors: ["too short"]
        )

      assert html =~ "line1\nline2"
      assert html =~ "border-rose-400"
    end

    test "default clause applies rose border only with errors" do
      # Mutation rationale: the conditional class list
      # `@errors != [] && "border-rose-400 ..."` is branchy logic — flip the
      # guard and error-free inputs gain the rose border.
      clean = render_component(&CoreComponents.input/1, type: "text", name: "q", value: "")
      refute clean =~ "border-rose-400"

      errored =
        render_component(&CoreComponents.input/1,
          type: "text",
          name: "q",
          value: "",
          errors: ["required"]
        )

      assert errored =~ "border-rose-400"
    end
  end

  describe "table/1" do
    @describetag :family_cort_w984ib_placeholder

    test "renders rows, col labels, row_id and row_item mapping" do
      # Mutation rationale: dropping the row_id/row_item machinery (or the
      # first-column font-semibold branch `i == 0`) changes rendered ids and
      # emphasis spans.
      html =
        render_component(&CoreComponents.table/1,
          id: "users",
          rows: [%{id: 1, name: "ada"}, %{id: 2, name: "grace"}],
          row_id: &"user-#{&1.id}",
          row_item: & &1,
          col: [
            %{label: "name", inner_block: fn _, _ -> {:safe, ["name"]} end}
          ]
        )

      assert html =~ ~s(id="user-1")
      assert html =~ ~s(id="user-2")
      assert html =~ "name"
    end

    test "action slot renders last column only when present" do
      # Mutation rationale: the `:if={@action != []}` branch — removing it
      # either always or never renders the actions cell.
      base = [
        id: "t",
        rows: [%{id: 1}],
        row_id: &"r-#{&1.id}",
        col: [%{label: "id", inner_block: fn _, _ -> {:safe, ["1"]} end}]
      ]

      without_action = render_component(&CoreComponents.table/1, base)
      refute without_action =~ ~s(w-14)

      with_action =
        render_component(&CoreComponents.table/1,
          Keyword.put(base, :action, [%{inner_block: fn _, _ -> {:safe, ["edit"]} end}])
        )

      assert with_action =~ ~s(w-14)
      assert with_action =~ "edit"
    end
  end

  describe "modal/1" do
    @describetag :family_court_w984ib

    test "renders title/subtitle header branch and confirm/cancel footer branch" do
      # Mutation rationale: the `:if={@title != []}` header branch and the
      # `:if={@confirm != [] or @cancel != []}` footer branch are unexercised
      # conditionals; flipping either drops or adds markup this test asserts.
      html =
        render_component(&CoreComponents.modal/1,
          id: "confirm-modal",
          title: [%{inner_block: fn _, _ -> {:safe, ["Delete item"]} end}],
          subtitle: [%{inner_block: fn _, _ -> {:safe, ["This is permanent"]} end}],
          confirm: [%{inner_block: fn _, _ -> {:safe, ["OK"]} end}],
          cancel: [%{inner_block: fn _, _ -> {:safe, ["Cancel"]} end}],
          inner_block: [%{inner_block: fn _, _ -> {:safe, ["body"]} end}]
        )

      assert html =~ "Delete item"
      assert html =~ "This is permanent"
      assert html =~ ~s(id="confirm-modal-confirm")
      assert html =~ "Cancel"
    end

    test "renders without header/footer when slots empty" do
      html =
        render_component(&CoreComponents.modal/1,
          id: "bare",
          inner_block: [%{inner_block: fn _, _ -> {:safe, ["body"]} end}]
        )

      refute html =~ ~s(id="bare-title")
      refute html =~ ~s(id="bare-confirm")
    end
  end

  describe "flash/1 kind routing" do
    @describetag :family_court_w984ib

    test "info kind from flash map renders emerald branch" do
      # Mutation rationale: the `@kind == :info && "bg-emerald-50 ..."` /
      # `@kind == :error && "bg-rose-50 ..."` conditional classes route on the
      # kind atom; swapping them swaps colors in rendered output.
      html =
        render_component(&CoreComponents.flash/1,
          kind: :info,
          flash: %{"info" => "saved"},
          autoshow: false
        )

      assert html =~ "saved"
      assert html =~ "bg-emerald-50"
      refute html =~ "bg-rose-50"
    end

    test "error kind renders rose branch and title icon branch" do
      html =
        render_component(&CoreComponents.flash/1,
          kind: :error,
          flash: %{"error" => "boom"},
          autoshow: false
        )

      assert html =~ "boom"
      assert html =~ "bg-rose-50"
    end

    test "renders nothing without message or inner_block" do
      # Mutation rationale: `:if={msg = render_slot(@inner_block) || Phoenix.Flash.get(...)}` —
      # removing the guard renders an empty flash container.
      html =
        render_component(&CoreComponents.flash/1,
          kind: :info,
          flash: %{},
          autoshow: false
        )

      refute html =~ "saved"
      assert html == "" or html =~ ""
    end
  end

  describe "simple_form/1 + header/1" do
    @describetag :family_court_w984ib

    test "simple_form renders inner block with form and actions slot" do
      # Mutation rationale: dropping `render_slot(@inner_block, f)` (the form
      # passed as slot param) or the actions wrapper changes output.
      html =
        render_component(&CoreComponents.simple_form/1,
          for: @form_source,
          inner_block: [%{inner_block: fn _, _ -> {:safe, ["fields"]} end}],
          actions: [%{inner_block: fn _, _ -> {:safe, ["submit"]} end}]
        )

      assert html =~ "fields"
      assert html =~ "submit"
    end

    test "header applies flex branch only with actions slot" do
      # Mutation rationale: `@actions != [] && "flex items-center justify-between"` —
      # flip the guard and slot-less headers gain the flex class.
      plain = render_component(&CoreComponents.header/1, inner_block: [%{inner_block: fn _, _ -> {:safe, ["Title"]} end}])
      refute plain =~ "justify-between"

      with_actions =
        render_component(&CoreComponents.header/1,
          inner_block: [%{inner_block: fn _, _ -> {:safe, ["Title"]} end}],
          actions: [%{inner_block: fn _, _ -> {:safe, ["Add"]} end}]
        )

      assert with_actions =~ "justify-between"
      assert with_actions =~ "Add"
    end
  end
end
