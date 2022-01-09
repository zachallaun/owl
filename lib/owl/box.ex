defmodule Owl.Box do
  @moduledoc """
  Allows wrapping data to boxes.
  """
  @border_styles %{
    none: %{
      top_left: "",
      top: "",
      top_right: "",
      right: "",
      left: "",
      bottom_left: "",
      bottom: "",
      bottom_right: ""
    },
    solid: %{
      top_left: "┌",
      top: "─",
      top_right: "┐",
      right: "│",
      left: "│",
      bottom_left: "└",
      bottom: "─",
      bottom_right: "┘"
    },
    double: %{
      top_left: "╔",
      top: "═",
      top_right: "╗",
      right: "║",
      left: "║",
      bottom_left: "╚",
      bottom: "═",
      bottom_right: "╝"
    }
  }
  @title_padding_left 1
  @title_padding_right 4
  @doc """
  Wraps data into a box.

  Options are self-descriptive in definition of the type `t:option/0`, numbers mean number of symbols.

  ## Examples

      iex> "Owl" |> Owl.Box.new() |> to_string()
      \"""
      ┌───┐
      │Owl│
      └───┘
      \""" |> String.trim_trailing()


      iex> "Hello\\nworld!"
      ...> |> Owl.Box.new(
      ...>   title: "Greeting!",
      ...>   min_width: 20,
      ...>   horizontal_align: :center,
      ...>   border_style: :double
      ...> )
      ...> |> to_string()
      \"""
      ╔═Greeting!════════╗
      ║      Hello       ║
      ║      world!      ║
      ╚══════════════════╝
      \""" |> String.trim_trailing()

      iex> "Success"
      ...> |> Owl.Box.new(
      ...>   min_width: 20,
      ...>   min_height: 3,
      ...>   border_style: :none,
      ...>   horizontal_align: :right,
      ...>   vertical_align: :bottom
      ...> )
      ...> |> to_string()
      \"""
                          
                          
                   Success
      \""" |> String.trim_trailing()

      iex> "OK"
      ...> |> Owl.Box.new(min_height: 5, vertical_align: :middle)
      ...> |> to_string()
      \"""
      ┌──┐
      │  │
      │OK│
      │  │
      └──┘
      \""" |> String.trim_trailing()

      iex> "VeryLongLine" |> Owl.Box.new(max_width: 6) |> to_string()
      \"""
      ┌────┐
      │Very│
      │Long│
      │Line│
      └────┘
      \""" |> String.trim_trailing()

      iex> "VeryLongLine" |> Owl.Box.new(max_width: 4, border_style: :none) |> to_string()
      \"""
      Very
      Long
      Line
      \""" |> String.trim_trailing()

      iex> "Green!"
      ...> |> Owl.Data.tag(:green)
      ...> |> Owl.Box.new(title: Owl.Data.tag("Red!", :red))
      ...> |> Owl.Data.tag(:cyan)
      ...> |> Owl.Data.to_ansidata()
      ...> |> to_string()
      \"""
      \e[36m┌─\e[31mRed!\e[36m────┐\e[39m
      \e[36m│\e[32mGreen!\e[36m   │\e[39m
      \e[36m└─────────┘\e[39m\e[0m
      \""" |> String.trim_trailing()
  """
  @type option ::
          {:padding_top, non_neg_integer()}
          | {:padding_bottom, non_neg_integer()}
          | {:padding_right, non_neg_integer()}
          | {:padding_left, non_neg_integer()}
          | {:min_height, non_neg_integer()}
          | {:min_width, non_neg_integer()}
          | {:max_width, non_neg_integer() | :infinity}
          | {:horizontal_align, :left | :center | :right}
          | {:vertical_align, :top | :middle | :bottom}
          | {:border_style, :solid | :double | :none}
          | {:title, nil | Owl.Data.t()}
  @spec new(Owl.Data.t(), [option()]) :: Owl.Data.t()
  def new(data, opts \\ []) do
    padding_top = Keyword.get(opts, :padding_top, 0)
    padding_bottom = Keyword.get(opts, :padding_bottom, 0)
    padding_left = Keyword.get(opts, :padding_left, 0)
    padding_right = Keyword.get(opts, :padding_right, 0)
    min_width = Keyword.get(opts, :min_width, 0)
    min_height = Keyword.get(opts, :min_height, 0)
    horizontal_align = Keyword.get(opts, :horizontal_align, :left)
    vertical_align = Keyword.get(opts, :vertical_align, :top)
    border_style = Keyword.get(opts, :border_style, :solid)
    border_symbols = Map.fetch!(@border_styles, border_style)
    title = Keyword.get(opts, :title)

    max_width = opts[:max_width] || Owl.IO.columns() || :infinity

    max_width =
      if is_integer(max_width) and max_width < min_width do
        min_width
      else
        max_width
      end

    max_inner_width =
      case max_width do
        :infinity -> :infinity
        width -> width - borders_size(border_style) - padding_right - padding_left
      end

    lines = Owl.Data.lines(data)

    lines =
      case max_inner_width do
        :infinity -> lines
        max_width -> Enum.flat_map(lines, fn line -> Owl.Data.chunk_every(line, max_width) end)
      end

    data_height = length(lines)

    inner_height =
      max(
        data_height,
        min_height - borders_size(border_style) - padding_bottom - padding_top
      )

    {padding_before, padding_after} =
      case vertical_align do
        :top ->
          {padding_top, padding_bottom + inner_height - data_height}

        :middle ->
          to_center = div(inner_height - data_height, 2)
          {padding_top + to_center, inner_height - data_height - to_center + padding_bottom}

        :bottom ->
          {padding_bottom + inner_height - data_height, padding_top}
      end

    lines =
      List.duplicate({[], 0}, padding_before) ++
        Enum.map(lines, fn line ->
          {line, Owl.Data.length(line)}
        end) ++ List.duplicate({[], 0}, padding_after)

    min_width_required_by_title =
      if is_nil(title) do
        0
      else
        Owl.Data.length(title) + @title_padding_left + @title_padding_right +
          borders_size(border_style)
      end

    if is_integer(max_width) and min_width_required_by_title > max_width do
      raise ArgumentError, "`:title` is too big for given `:max_width`"
    end

    inner_width =
      Enum.max([
        min_width - padding_right - padding_left - borders_size(border_style),
        min_width_required_by_title - padding_right - padding_left - borders_size(border_style)
        | Enum.map(lines, fn {_line, line_length} -> line_length end)
      ])

    top_border =
      case border_style do
        :none ->
          []

        _ ->
          [
            border_symbols.top_left,
            if is_nil(title) do
              String.duplicate(border_symbols.top, inner_width + padding_left + padding_right)
            else
              [
                String.duplicate(border_symbols.top, @title_padding_left),
                title,
                String.duplicate(
                  border_symbols.top,
                  inner_width - (min_width_required_by_title - borders_size(border_style)) +
                    padding_left + padding_right
                ),
                String.duplicate(border_symbols.top, @title_padding_right)
              ]
            end,
            border_symbols.top_right,
            "\n"
          ]
      end

    bottom_border =
      case border_style do
        :none ->
          []

        _ ->
          [
            if(inner_height > 0, do: "\n", else: []),
            border_symbols.bottom_left,
            String.duplicate(border_symbols.bottom, inner_width + padding_left + padding_right),
            border_symbols.bottom_right
          ]
      end

    [
      top_border,
      lines
      |> Enum.map(fn {line, length} ->
        {padding_before, padding_after} =
          case horizontal_align do
            :left ->
              {padding_left, inner_width - length + padding_right}

            :right ->
              {inner_width - length + padding_left, padding_right}

            :center ->
              to_center = div(inner_width - length, 2)
              {padding_left + to_center, inner_width - length - to_center + padding_right}
          end

        [
          border_symbols.left,
          String.duplicate(" ", padding_before),
          line,
          String.duplicate(" ", padding_after),
          border_symbols.right
        ]
      end)
      |> Owl.Data.unlines(),
      bottom_border
    ]
  end

  defp borders_size(:none = _border_style), do: 0
  defp borders_size(_border_style), do: 2
end
