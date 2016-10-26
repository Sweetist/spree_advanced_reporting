module Spree
  class TransactionReport
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
      transactions = []
      totals = {}
      totals.default = 0

      @labels = Set.new

      @orders.each do |order|
        unless order.paid?
          next
        end
        order_infos = {}
        order_infos.default = 0

        totals["subtotal"] +=order.item_total

        order.all_adjustments.each do |adjustment|
          @labels.add adjustment.label
          order_infos[adjustment.label] += adjustment.amount
          totals[adjustment.label] += adjustment.amount
        end

        totals["total"] += order.total
        # sort the order info to make sure they fit the table header

        lines << ReportLine.new(
            order.number,
            order.completed_at,
            order_infos,
            order.item_total,
            order.total
        )

      end


      lines << ReportLine.new(
          "",
          " ",
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
          'number',
          'date',
          'subtotal',
        ]
        @labels.each do |label|
          arr << label
        end
        arr << 'total'
        csv << arr
        lines.each do |li|
          arr = [li.number, li.date, li.subtotal]
          @labels.each do |label|
            arr << li.order_infos[label]
          end
          arr << li.total
          csv << arr
        end
      end
    end

    ReportLine = Struct.new(
        :number,
        :date,
        :order_infos,
        :subtotal,
        :total
    )

  end
end
