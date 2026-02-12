module Ultraviolet
  struct HashMapEntry
    property value : UInt64
    property oldcount : Int32
    property newcount : Int32
    property oldindex : Int32
    property newindex : Int32

    def initialize(
      @value : UInt64 = 0_u64,
      @oldcount : Int32 = 0,
      @newcount : Int32 = 0,
      @oldindex : Int32 = 0,
      @newindex : Int32 = 0,
    )
    end
  end

  NEW_INDEX = -1

  class TerminalRenderer
    private def hash_line(line : Line) : UInt64
      # Note: Go uses hash/maphash with random per-instance seeding.
      # Crystal uses FNV-1a (64-bit) for simplicity and good distribution.
      # Both are non-cryptographic hash functions suitable for line comparison.
      hash = 1469598103934665603_u64
      line.cells.each do |cell|
        cell.content.each_byte do |byte|
          hash ^= byte.to_u64
          hash &*= 1099511628211_u64
        end
      end
      hash
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def update_hashmap(newbuf : RenderBuffer) : Nil
      height = newbuf.height
      curbuf = @curbuf
      return unless curbuf

      if @oldhash.size >= height && @newhash.size >= height
        i = 0
        while i < height
          if newbuf.touched.empty? || newbuf.touched[i]?
            @oldhash[i] = hash_line(curbuf.line_at(i))
            @newhash[i] = hash_line(newbuf.line_at(i))
          end
          i += 1
        end
      else
        @oldhash = Array(UInt64).new(height, 0_u64) if @oldhash.size != height
        @newhash = Array(UInt64).new(height, 0_u64) if @newhash.size != height
        i = 0
        while i < height
          @oldhash[i] = hash_line(curbuf.line_at(i))
          @newhash[i] = hash_line(newbuf.line_at(i))
          i += 1
        end
      end

      @hashtab = Array(HashMapEntry).new((height + 1) * 2) { HashMapEntry.new }
      i = 0
      while i < height
        hashval = @oldhash[i]
        idx = 0
        while idx < @hashtab.size && @hashtab[idx].value != 0_u64
          break if @hashtab[idx].value == hashval
          idx += 1
        end

        entry = @hashtab[idx]
        entry.value = hashval
        entry.oldcount += 1
        entry.oldindex = i
        @hashtab[idx] = entry
        i += 1
      end

      @oldnum = Array(Int32).new(height, NEW_INDEX) if @oldnum.size < height
      i = 0
      while i < height
        hashval = @newhash[i]
        idx = 0
        while idx < @hashtab.size && @hashtab[idx].value != 0_u64
          break if @hashtab[idx].value == hashval
          idx += 1
        end

        entry = @hashtab[idx]
        entry.value = hashval
        entry.newcount += 1
        entry.newindex = i
        @hashtab[idx] = entry
        @oldnum[i] = NEW_INDEX
        i += 1
      end

      i = 0
      while i < @hashtab.size && @hashtab[i].value != 0_u64
        entry = @hashtab[i]
        if entry.oldcount == 1 && entry.newcount == 1 && entry.oldindex != entry.newindex
          @oldnum[entry.newindex] = entry.oldindex
        end
        i += 1
      end

      grow_hunks(newbuf)

      i = 0
      while i < height
        while i < height && @oldnum[i] == NEW_INDEX
          i += 1
        end
        break if i >= height

        start = i
        shift = @oldnum[i] - i
        i += 1
        while i < height && @oldnum[i] != NEW_INDEX && @oldnum[i] - i == shift
          i += 1
        end
        size = i - start
        if size < 3 || size + Math.min(size // 8, 2) < Ultraviolet.abs(shift)
          while start < i
            @oldnum[start] = NEW_INDEX
            start += 1
          end
        end
      end

      grow_hunks(newbuf)
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def scroll_oldhash(n : Int32, top : Int32, bot : Int32) : Nil
      return if @oldhash.empty?

      size = bot - top + 1 - Ultraviolet.abs(n)
      if n > 0
        copy_count = size
        i = 0
        while i < copy_count
          @oldhash[top + i] = @oldhash[top + n + i]
          i += 1
        end
        if curbuf = @curbuf
          i = bot
          while i > bot - n
            @oldhash[i] = hash_line(curbuf.line_at(i))
            i -= 1
          end
        end
      elsif n < 0
        copy_count = size
        i = 0
        while i < copy_count
          @oldhash[top - n + i] = @oldhash[top + i]
          i += 1
        end
        if curbuf = @curbuf
          i = top
          while i < top - n
            @oldhash[i] = hash_line(curbuf.line_at(i))
            i += 1
          end
        end
      end
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def grow_hunks(newbuf : RenderBuffer) : Nil
      back_limit = 0
      back_ref_limit = 0
      i = 0
      height = newbuf.height
      while i < height && @oldnum[i] == NEW_INDEX
        i += 1
      end
      while i < height
        start = i
        shift = @oldnum[i] - i

        i = start + 1
        while i < height && @oldnum[i] != NEW_INDEX && @oldnum[i] - i == shift
          i += 1
        end

        end_idx = i
        while i < height && @oldnum[i] == NEW_INDEX
          i += 1
        end

        next_hunk = i
        forward_limit = i
        forward_ref_limit = if i >= height || @oldnum[i] >= i
                              i
                            else
                              @oldnum[i]
                            end

        i = start - 1

        if shift < 0
          back_limit = back_ref_limit + (-shift)
        end
        while i >= back_limit
          if @newhash[i] == @oldhash[i + shift] || cost_effective(newbuf, i + shift, i, shift < 0)
            @oldnum[i] = i + shift
          else
            break
          end
          i -= 1
        end

        i = end_idx
        if shift > 0
          forward_limit = forward_ref_limit - shift
        end
        while i < forward_limit
          if @newhash[i] == @oldhash[i + shift] || cost_effective(newbuf, i + shift, i, shift > 0)
            @oldnum[i] = i + shift
          else
            break
          end
          i += 1
        end

        back_limit = i
        back_ref_limit = back_limit
        back_ref_limit += shift if shift > 0

        i = next_hunk
      end
    end

    # ameba:enable Metrics/CyclomaticComplexity

    private def cost_effective(newbuf : RenderBuffer, from : Int32, to : Int32, blank : Bool) : Bool
      return false if from == to

      new_from = @oldnum[from]
      new_from = from if new_from == NEW_INDEX

      cost_before = 0
      if blank
        cost_before = update_cost_blank(newbuf, newbuf.line_at(to))
      else
        curbuf = @curbuf
        return false unless curbuf
        cost_before = update_cost(newbuf, curbuf.line_at(to), newbuf.line_at(to))
      end
      curbuf = @curbuf
      return false unless curbuf
      cost_before += update_cost(newbuf, curbuf.line_at(new_from), newbuf.line_at(from))

      cost_after = 0
      if new_from == from
        cost_after = update_cost_blank(newbuf, newbuf.line_at(from))
      else
        curbuf = @curbuf
        return false unless curbuf
        cost_after = update_cost(newbuf, curbuf.line_at(new_from), newbuf.line_at(from))
      end
      curbuf = @curbuf
      return false unless curbuf
      cost_after += update_cost(newbuf, curbuf.line_at(from), newbuf.line_at(to))

      cost_before >= cost_after
    end

    private def update_cost(_newbuf : RenderBuffer, from : Line, to : Line) : Int32
      cost = 0
      fidx = 0
      tidx = 0
      curbuf = @curbuf
      return 0 unless curbuf
      i = curbuf.width
      while i > 0
        cost += 1 unless Ultraviolet.cell_equal?(from.at(fidx), to.at(tidx))
        i -= 1
        fidx += 1
        tidx += 1
      end
      cost
    end

    private def update_cost_blank(_newbuf : RenderBuffer, to : Line) : Int32
      blank = clear_blank
      cost = 0
      tidx = 0
      curbuf = @curbuf
      return 0 unless curbuf
      i = curbuf.width
      while i > 0
        cost += 1 unless Ultraviolet.cell_equal?(blank, to.at(tidx))
        i -= 1
        tidx += 1
      end
      cost
    end
  end
end
