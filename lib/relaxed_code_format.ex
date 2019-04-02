defmodule RelaxedCodeFormat do
  @moduledoc """
  A Code format variant that relaxes spacing between syntaxtic punctuation
  and names. Adds spaces before/after (, {, [, << which makes code easier
  to read for more relaxed code reading.
  """

  @doc ~S"""
  Formats the given code `string`. This is a shortened doc from
  the original in Code. Please see Code.format_string! for more
  info on the Design and "Keeping user's formattion" topics.

  The formatter receives a string representing Elixir code and
  returns iodata representing the formatted code according to
  pre-defined rules.

  ## Options

    * `:file` - the file which contains the string, used for error
      reporting

    * `:line` - the line the string starts, used for error reporting

    * `:line_length` - the line length to aim for when formatting
      the document. Defaults to 98. Note this value is used as
      reference but it is not enforced by the formatter as sometimes
      user intervention is required. See "Running the formatter"
      section

    * `:locals_without_parens` - a keyword list of name and arity
      pairs that should be kept without parens whenever possible.
      The arity may be the atom `:*`, which implies all arities of
      that name. The formatter already includes a list of functions
      and this option augments this list.

    * `:rename_deprecated_at` - rename all known deprecated functions
      at the given version to their non-deprecated equivalent. It
      expects a valid `Version` which is usually the minimum Elixir
      version supported by the project.

  """
  @doc since: "1.6.0"
  @spec format_string!( binary, keyword ) :: iodata
  def format_string!( string, opts \\ [ ] ) when is_binary( string ) and is_list( opts ) do
    line_length = Keyword.get( opts, :line_length, 98 )
    algebra1 = Code.Formatter.to_algebra!( string, opts )
    algebra = relax_space( algebra1 )
    Inspect.Algebra.format( algebra, line_length )
  end

  @doc """
  Formats a file.

  See `format_string!/2` for more information on code formatting and
  available options.
  """
  @doc since: "1.6.0"
  @spec format_file!( binary, keyword ) :: iodata
  def format_file!( file, opts \\ [ ] ) when is_binary( file ) and is_list( opts ) do
    string = File.read!( file )
    formatted = format_string!( string, [ file: file, line: 1 ] ++ opts )
    [ formatted, ?\n ]
  end

  # In order: {, (, [, <<
  @opens [ 
    << 123 >>,
    << 40 >>,
    << 91 >>,
    << 60, 60 >>
  ]

  # In order: }, ), ], >>
  @closes [ 
    << 125 >>,
    << 41 >>,
    << 93 >>,
    << 62, 62 >>
  ]

  def relax_space( tup ) do
    case tup do
      { :doc_cons, { :doc_break, "", :strict }, c } when c in @closes ->
        { :doc_cons, { :doc_break, " ", :strict }, c }

      { :doc_cons, cons, c } when c in @closes ->
        { :doc_cons, relax_space( cons ), { :doc_cons, { :doc_break, " ", :flex }, c } }

      # Open curly, square, paren
      { ty, c, cons } when c in @opens ->
        { ty, c, { :doc_cons, { :doc_break, " ", :flex }, relax_space( cons ) } }

      { :doc_cons, cona, conb } ->
        { :doc_cons, relax_space( cona ), relax_space( conb ) }

      { :doc_nest, cona, x, y } ->
        { :doc_nest, relax_space( cona ), x, y }

      { :doc_group, cona, x } ->
        { :doc_group, relax_space( cona ), x }

      { :doc_force, con } ->
        { :doc_force, relax_space( con ) }

      { z, a, b } ->
        { z, relax_space( a ), relax_space( b ) }

      v when is_tuple( v ) ->
        v

      v ->
        v
    end
  end
end
