require 'rspec/given'
require 'sudoku'

AllNumbers = Set[1,2,3,4,5,6,7,8,9]

describe Cell do

  def create_group_with(cell, *numbers)
    g = Group.new
    g << cell
    numbers.each do |n|
      c = Cell.new
      c.number = n
      g << c
    end
    g
  end

  Given(:cell) { Cell.new("C25") }

  Then { cell.to_s.should == "C25" }
  Then { cell.inspect.should ==  "C25" }
  Then { cell.number.should be_nil }
  Then { cell.available_numbers.should == AllNumbers }

  context 'when setting the number' do
    When { cell.number = 4 }
    Then { cell.number.should == 4 }
    Then { cell.available_numbers.should == Set[] }
  end

  context 'when setting number to zero' do
    When { cell.number = 0 }
    Then { cell.number.should be_nil }
    Then { cell.available_numbers.should == AllNumbers }
  end

  context 'within a group' do
    Given { create_group_with(cell, 3, 4, 5) }
    Then { cell.available_numbers.should == AllNumbers - Set[3, 4, 5] }
  end
end

describe Group do
  Given(:group) { Group.new }

  Given(:cells) { (1..10).map { |i| Cell.new("C#{i}") } }
  Given { cells.each do |c| group << c end }

  context "with no numbers assigned" do
    Then { group.numbers.should == Set[] }
    Then { group.open_numbers.should == AllNumbers }
    Then { group.cells_open_for(1).should == Set[*cells] }
    Then {
      group.open_cells_map.should == Hash[ AllNumbers.map { |n| [n, Set[*cells]] } ]
    }
  end

  context 'with some numbers' do
    Given {
      [3,6].each do |i| cells[i].number = i end
    }

    Given(:except36) { Set[*cells] - Set[cells[3], cells[6]] }

    Then { group.numbers.should == Set[3,6] }
    Then { group.open_numbers.should == AllNumbers - group.numbers }
    Then { group.cells_open_for(3).should == Set[] }
    Then { group.cells_open_for(1).should == Set[*cells] - Set[cells[3], cells[6]] }

    Then {
      group.open_cells_map.should == Hash[ [1,2,4,5,7,8,9].map { |n| [n, except36] } ]
    }
  end

  context 'with all numbers' do
    Given {
      (1..9).each do |i| cells[i].number = i end
    }
    Then { group.numbers.should == AllNumbers }
    Then { group.open_numbers.should == Set[] }
    Then { group.cells_open_for(1).should == Set[] }
    Then { group.open_cells_map.should == {} }
  end
end

module Puzzles
  Wiki =
    "53  7    " +
    "6  195   " +
    " 98    6 " +
    "8   6   3" +
    "4  8 3  1" +
    "7   2   6" +
    " 6    28 " +
    "   419  5" +
    "    8  79"

  WikiEncoding = Wiki.gsub(/ /, '.')

  WikiSolution =
    "534678912" +
    "672195348" +
    "198342567" +
    "859761423" +
    "426853791" +
    "713924856" +
    "961537284" +
    "287419635" +
    "345286179"

  Medium =
    " 4   7 3 " +
    "  85  1  " +
    " 15 3  9 " +
    "5   7 21 " +
    "  6   8  " +
    " 81 6   9" +
    " 2  4 57 " +
    "  7  29  " +
    " 5 7   8 "

  MediumSolution =
    "942187635" +
    "368594127" +
    "715236498" +
    "593478216" +
    "476921853" +
    "281365749" +
    "829643571" +
    "137852964" +
    "654719382"

  Evil =
    "  53 694 " +
    " 3 1    6" +
    "       3 " +
    "7  9     " +
    " 1  3  2 " +
    "     2  7" +
    " 6       " +
    "8    7 5 " +
    " 436 81  "

  EvilSolution =
    "285376941" +
    "439125786" +
    "176849235" +
    "752981364" +
    "618734529" +
    "394562817" +
    "567213498" +
    "821497653" +
    "943658172"
end

describe Board do
  Given(:board) { Board.new }

  Then { board.inspect.should =~ %r(^<Board \.{81}>$) }
  Then { board.cells.size.should == 9 * 9 }
  Then { board.groups.size.should == 3 * 9 }
  Then {
    board.cells.each do |cell|
      cell.available_numbers.should == Set[*(1..9)]
    end
  }

  describe "#parse" do
    Given(:puzzle) { Puzzles::Wiki }

    When(:result) { board.parse(puzzle) }

    context "with a good encoding" do
      # Invariant { result.should_not have_failed }

      context "and standard line encoding" do
        Then { board.encoding.should == Puzzles::WikiEncoding }
      end

      context "and dots instead of spaces" do
        Given(:puzzle) { Puzzles::Wiki.gsub(/ /, '.') }
        Then { board.encoding.should == Puzzles::WikiEncoding }
      end

      context "and DOS line encodings" do
        Given(:puzzle) { Puzzles::Wiki.gsub(/\n/, "\r\n") }
        Then { board.encoding.should == Puzzles::WikiEncoding }
      end

      context "and comments" do
        Given(:puzzle) { "# Standard Wiki example\n\n" + Puzzles::Wiki }
        Then { board.encoding.should == Puzzles::WikiEncoding }
      end
    end

    context "with a bad encoding" do
      context "that is short" do
        Given(:puzzle) { Puzzles::Wiki[0...-1] }
        Then { result.should have_failed(Board::ParseError, /too short/i) }
      end

      context "that is long" do
        Given(:puzzle) { Puzzles::Wiki + "." }
        Then { result.should have_failed(Board::ParseError, /too long/i) }
      end

      context "that has invalid characters" do
        Given(:puzzle) { p = Puzzles::Wiki.dup; p[39] = "x"; p }
        Then { result.should have_failed(Board::ParseError, /invalid.*char/i) }
      end
    end
  end

  describe "solving" do
    Given(:board) { Board.new.parse(puzzle) }

    When { board.solve }

    Invariant { board.should be_solved }

    context "with the wiki puzzle" do
      Given(:puzzle) { Puzzles::Wiki }
      Then { board.encoding.should == Puzzles::WikiSolution }
    end

    context "with the medium puzzle" do
      Given(:puzzle) { Puzzles::Medium }
      Then { board.encoding.should == Puzzles::MediumSolution }
    end

    context 'with the Evil Puzzle' do
      Given(:puzzle) { Puzzles::Evil }
      Then { board.encoding.should == Puzzles::EvilSolution }
    end
  end
end

describe "Sudoku Solver" do
  WikiPuzzleFile = 'puzzles/wiki.sud'
  SOLUTION = %{5 3 4  6 7 8  9 1 2
6 7 2  1 9 5  3 4 8
1 9 8  3 4 2  5 6 7

8 5 9  7 6 1  4 2 3
4 2 6  8 5 3  7 9 1
7 1 3  9 2 4  8 5 6

9 6 1  5 3 7  2 8 4
2 8 7  4 1 9  6 3 5
3 4 5  2 8 6  1 7 9}

  SOL_PATTERN = SOLUTION.gsub(/\s+/,'\s+')

  def redirect_output
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  Given(:solver) { SudokuSolver.new }

  describe 'solve a puzzle' do
    Given(:result) {
      redirect_output do
        solver.run([WikiPuzzleFile])
      end
    }
    Then { result.should =~ /#{SOL_PATTERN}/ }
  end

  describe 'complain if no file given' do
    Given(:result) {
      redirect_output do
        result = nil
        begin
          solver.run([])
        rescue SystemExit => ex
          result = ex
        end
        result
      end
    }
    Then { result.should =~ /Usage:/ }
  end
end
