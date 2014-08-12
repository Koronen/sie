require "active_support/time"

module Sie
  class FinancialYears
    method_object :between,
      :from_date, :to_date, [ :start_month ]

    def between
      from_date.year.upto(to_date.year).map { |year|
        FinancialYear.date_range(year, start_month)
      }
    end
  end

  class FinancialYear
    method_object :date_range,
      :year, :start_month

    def date_range
      start_of_year..end_of_year
    end

    private

    def start_of_year
      Date.new(year, start_month, 1)
    end

    def end_of_year
      a_year_later = start_of_year >> 11
      Date.new(a_year_later.year, a_year_later.month, -1)
    end
  end
end