require "attr_extras"
require "sie/document/voucher_series"
require "sie/document/renderer"
require "active_support/core_ext/module/delegation"

module Sie
  class Document
    pattr_initialize :data_source
    # Because fortnox imposes these limits
    DESCRIPTION_LENGTH_MAX = 30

    def render
      add_header
      add_financial_years
      add_accounts
      add_balances
      add_vouchers

      renderer.render
    end

    private

    delegate :program, :program_version, :generated_on, :company_name,
      :accounts, :balance_account_numbers, :closing_account_numbers,
      :balance_before, :each_voucher,
      to: :data_source

    def add_header
      add_line("FLAGGA", 0)
      add_line("PROGRAM", program, program_version)
      add_line("FORMAT", "PC8")
      add_line("GEN", generated_on)
      add_line("SIETYP", 4)
      add_line("FNAMN", company_name)
    end

    def add_financial_years
      financial_years.each_with_index do |date_range, index|
        add_line("RAR", -index, date_range.begin, date_range.end)
      end
    end

    def add_accounts
      accounts.each do |account|
        number      = account.fetch(:number)
        description = account.fetch(:description).slice(0, DESCRIPTION_LENGTH_MAX)

        add_line("KONTO", number, description)
      end
    end

    def add_balances
      financial_years.each_with_index do |date_range, index|
        add_balance_rows("IB", -index, balance_account_numbers, date_range.begin)
        add_balance_rows("UB", -index, balance_account_numbers, date_range.end)
        add_balance_rows("RES", -index, closing_account_numbers, date_range.end)
      end
    end

    def add_balance_rows(label, year_index, account_numbers, date, &block)
      account_numbers.each do |account_number|
        balance = balance_before(account_number, date)
        add_line(label, year_index, account_number, balance)
      end
    end

    def add_vouchers
      each_voucher do |voucher|
        add_voucher(voucher)
      end
    end

    def add_voucher(opts)
      number         = opts.fetch(:number)
      booked_on      = opts.fetch(:booked_on)
      description    = opts.fetch(:description).slice(0, DESCRIPTION_LENGTH_MAX)
      voucher_lines  = opts.fetch(:voucher_lines)
      voucher_series = opts.fetch(:series) {
        creditor = opts.fetch(:creditor)
        type = opts.fetch(:type)
        VoucherSeries.for(creditor, type)
      }

      add_line("VER", voucher_series, number, booked_on, description)

      add_array do
        voucher_lines.each do |line|
          account_number = line.fetch(:account_number)
          amount         = line.fetch(:amount)
          booked_on      = line.fetch(:booked_on)
          # Some SIE-importers (fortnox) cannot handle descriptions longer than 30 characters,
          # but the specification has no limit.
          description    = line.fetch(:description).slice(0, DESCRIPTION_LENGTH_MAX)

          add_line("TRANS", account_number, Renderer::EMPTY_ARRAY, amount, booked_on, description)

          # Some consumers of SIE cannot handle single voucher lines (fortnox), so add another empty one to make
          # it balance. The spec just requires the sum of lines to be 0, so single lines with zero amount would conform,
          # but break for these implementations.
          if voucher_lines.size < 2 && amount.zero?
            add_line("TRANS", account_number, Renderer::EMPTY_ARRAY, amount, booked_on, description)
          end
        end
      end
    end

    delegate :add_line, :add_array, to: :renderer

    def renderer
      @renderer ||= Renderer.new
    end

    def financial_years
      data_source.financial_years.sort_by { |date_range| date_range.first }.reverse
    end
  end
end
