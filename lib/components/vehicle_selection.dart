import 'package:flutter/material.dart';

/// Modelo de datos para cada categoría de vehículo
class VehicleOption {
  final String id;
  final String name;
  final String subtitle;
  final String eta; // Tiempo estimado de llegada (ej. "3 min")
  final double price;
  final int capacity;
  final IconData icon;
  final bool isPromo;

  const VehicleOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.eta,
    required this.price,
    required this.capacity,
    required this.icon,
    this.isPromo = false,
  });
}

class VehicleSelectionWidget extends StatefulWidget {
  final List<VehicleOption> options;
  final String currencySymbol;
  final String? initialSelectedId;
  final ValueChanged<VehicleOption> onVehicleSelected;
  final ValueChanged<VehicleOption> onConfirmPressed;
  final ScrollController? scrollController; // Conectado al SlidingUpPanel

  const VehicleSelectionWidget({
    super.key,
    required this.options,
    required this.onVehicleSelected,
    required this.onConfirmPressed,
    this.currencySymbol = 'Gs.',
    this.initialSelectedId,
    this.scrollController,
  });

  @override
  State<VehicleSelectionWidget> createState() => _VehicleSelectionWidgetState();
}

class _VehicleSelectionWidgetState extends State<VehicleSelectionWidget> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId =
        widget.initialSelectedId ??
        (widget.options.isNotEmpty ? widget.options.first.id : '');
  }

  VehicleOption get _selectedVehicle => widget.options.firstWhere(
    (v) => v.id == _selectedId,
    orElse: () => widget.options.first,
  );

  /// Formatea el precio con separador de miles si es necesario
  String _formatPrice(double price) {
    if (widget.currencySymbol == 'Gs.') {
      final intVal = price.round().toString();
      final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
      return '${widget.currencySymbol} ${intVal.replaceAllMapped(reg, (Match m) => '${m[1]}.')}';
    }
    return '${widget.currencySymbol}${price.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      return const Center(
        child: Text('No hay vehículos disponibles en esta zona.'),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Elige un viaje',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1D1F),
                  ),
                ),
                Text(
                  'Tarifas estimadas',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: widget.options.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final vehicle = widget.options[index];
                    final isSelected = vehicle.id == _selectedId;

                    return _VehicleTile(
                      vehicle: vehicle,
                      isSelected: isSelected,
                      formattedPrice: _formatPrice(vehicle.price),
                      onTap: () {
                        setState(() => _selectedId = vehicle.id);
                        widget.onVehicleSelected(vehicle);
                      },
                    );
                  },
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () =>
                          widget.onConfirmPressed(_selectedVehicle),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Confirmar ${_selectedVehicle.name}',
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatPrice(_selectedVehicle.price),
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final VehicleOption vehicle;
  final bool isSelected;
  final String formattedPrice;
  final VoidCallback onTap;

  const _VehicleTile({
    required this.vehicle,
    required this.isSelected,
    required this.formattedPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? const Color(0xFF111827)
        : Colors.grey.shade200;
    final bgColor = isSelected ? const Color(0xFFF3F4F6) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                vehicle.icon,
                size: 28,
                color: isSelected
                    ? const Color(0xFF111827)
                    : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        vehicle.name,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1D1F),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                      Text(
                        '${vehicle.capacity}',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${vehicle.eta} • ${vehicle.subtitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formattedPrice,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1D1F),
                  ),
                ),
                if (vehicle.isPromo)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Más rápido',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
