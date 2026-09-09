import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/seat_model.dart';

class SeatGridView extends StatelessWidget {
  final Map<String, List<SeatModel>> seatRows;
  final Function(SeatModel seat)? onSeatTap;

  const SeatGridView({
    Key? key,
    required this.seatRows,
    this.onSeatTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (seatRows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No seat desks available for this shift.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend Header
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildLegendItem('Available', AppColors.seatAvailable),
            _buildLegendItem('Occupied', AppColors.seatOccupied),
            _buildLegendItem('My Seat', AppColors.seatMyBooked),
            _buildLegendItem('On Hold', AppColors.seatPending),
          ],
        ),
        const SizedBox(height: 16),
        // Rows List
        ...seatRows.entries.map((entry) {
          final rowLabel = entry.key;
          final seats = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Text(
                  'ROW $rowLabel',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.lightSubtext,
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.1,
                ),
                itemCount: seats.length,
                itemBuilder: (context, index) {
                  final seat = seats[index];
                  return _buildSeatCard(context, seat);
                },
              ),
              const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSeatCard(BuildContext context, SeatModel seat) {
    Color cardColor;
    Color textColor = Colors.white;

    if (seat.isMySeat) {
      cardColor = AppColors.seatMyBooked;
    } else if (seat.status == 'booked') {
      cardColor = AppColors.seatOccupied;
    } else if (seat.status == 'hold') {
      cardColor = AppColors.seatPending;
    } else {
      cardColor = AppColors.seatAvailable;
    }

    return InkWell(
      onTap: onSeatTap != null ? () => onSeatTap!(seat) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chair, size: 20, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              seat.seatNumber,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
