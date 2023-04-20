owl =
  """
     ,_,
    {o,o}
    /)  )
  ---"-"--
  """
  |> String.trim_trailing()

owl_height = 4
owl_width = 8

width = 60
height = 20
colors = [:red, :yellow, :cyan, :blue, :green] |> Map.new(fn c -> {to_string(c), c} end)
# two sides
borders_size = 2

Owl.LiveScreen.add_block(:demo,
  render: fn
    nil ->
      ""

    state ->
      owl
      |> Owl.Data.tag(state[:owl_color] || :cyan)
      |> Owl.Box.new(
        min_width: width,
        min_height: height,
        padding_top: state.padding_top,
        padding_left: state.padding_left
      )
      |> Owl.Data.tag(:magenta)
  end,
  on_input: fn input, state ->
    color = Map.get(colors, input, :cyan)
    Map.put(state, :owl_color, color)
  end
)

Task.async(fn ->
  Stream.iterate(
    %{
      padding_top: 10,
      padding_left: 30,
      vertical_shift: 1,
      horizontal_shift: -1
    },
    fn state ->
      horizontal_shift =
        cond do
          state.padding_left == 0 or width - state.padding_left - owl_width - borders_size == 0 ->
            state.horizontal_shift * -1

          state.padding_left > 0 ->
            state.horizontal_shift
        end

      vertical_shift =
        cond do
          state.padding_top == 0 or height - state.padding_top - owl_height - borders_size == 0 ->
            state.vertical_shift * -1

          state.padding_top > 0 ->
            state.vertical_shift
        end

      padding_left = state.padding_left + horizontal_shift
      padding_top = state.padding_top + vertical_shift

      Owl.LiveScreen.update(:demo, %{
        padding_left: padding_left,
        padding_top: padding_top
      })

      Process.sleep(200)

      %{
        padding_left: padding_left,
        padding_top: padding_top,
        vertical_shift: vertical_shift,
        horizontal_shift: horizontal_shift
      }
    end
  )
  |> Stream.run()
end)

:timer.sleep(:infinity)
