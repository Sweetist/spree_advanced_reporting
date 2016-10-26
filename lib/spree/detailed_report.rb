module Spree
  class DetailedReport
    def initialize(report_params)
      if !report_params[:begin_date] && !report_params[:end_date]
        @begin_date = Time.now - 1.month
        @end_date = Time.now
      else
        @begin_date = Date.strptime(report_params[:begin_date], '%d/%m/%Y').beginning_of_day
        @end_date =   Date.strptime(report_params[:end_date], '%d/%m/%Y').end_of_day
      end

      @orders = Order.
          eager_load(
              :all_adjustments,
              :valid_payments,
              shipments: [:selected_shipping_method],
              line_items: [:variant]
          ).
          where(completed_at: @begin_date..@end_date).
          where("spree_payments.state = 'completed'").
          order(:completed_at)


    end

    def line_items
      lines = []
      days = {}
      totals = {}
      totals.default = 0

      @labels = Set.new

      @orders.each do |order|
        unless order.paid?
          next
        end

        date = order.completed_at.to_date
        days[date] ||={}
        days[date]["subtotal"] ||=0
        days[date]["infos"] ||= {}
        days[date]["infos"].default = 0
        days[date]["total"] ||=0

        totals["subtotal"] ||=0
        totals["total"] ||=0

        days[date]["subtotal"] +=order.item_total
        totals["subtotal"] +=order.item_total

        order.all_adjustments.each do |adjustment|
          @labels.add adjustment.label
          days[date]["infos"][adjustment.label] += adjustment.amount
          totals[adjustment.label] += adjustment.amount
        end

        days[date]["total"] += order.total
        totals["total"] += order.total

      end


      days.each do |day, li|
          lines << ReportLine.new(
              day,
              li["infos"],
              li["subtotal"],
              li["total"]
          )
      end
      lines << ReportLine.new(
          "",
          totals,
          totals["subtotal"],
          totals["total"]
      )

      lines
    end

    def to_csv
      lines = self.line_items.collect()
      CSV.generate do |csv|
        arr = [
          'day',
          'subtotal',
        ]
        @labels.each do |label|
          arr << label
        end
        arr << 'total'
        csv << arr
        lines.each do |li|
          arr = [li.day, li.subtotal]
          @labels.each do |label|
            arr << li.infos[label]
          end
          arr << li.total
          csv << arr
        end
      end
    end

    ReportLine = Struct.new(
        :day,
        :infos,
        :subtotal,
        :total
    )

  end
end
