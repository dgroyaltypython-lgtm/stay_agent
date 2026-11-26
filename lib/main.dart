import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
const demoMode = apiBaseUrl == '';

void main() => runApp(const SereinAgentApp());

class SereinAgentApp extends StatelessWidget {
  const SereinAgentApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Serein Agent',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F4EF),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF183A35)),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF5F4EF), foregroundColor: Color(0xFF183A35), elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF183A35), width: 1.4)),
      ),
    ),
    home: const SessionGate(),
  );
}

class Booking {
  final int id, guests;
  final String reference, guest, phone, property, room, status, checkIn, checkOut, notes;
  final double total;
  const Booking({required this.id, required this.guests, required this.reference, required this.guest,
    required this.phone, required this.property, required this.room, required this.status,
    required this.checkIn, required this.checkOut, required this.total, this.notes = ''});

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
    id: j['id'] ?? 0, guests: int.tryParse('${j['guests'] ?? 1}') ?? 1,
    reference: '${j['reference'] ?? 'SE-0000'}',
    guest: '${j['customer_name'] ?? 'Guest'}', phone: '${j['customer_phone'] ?? ''}',
    property: '${j['property_name'] ?? 'Property'}', room: '${j['room_type_name'] ?? 'Standard'}',
    status: '${j['status'] ?? 'ENQUIRY'}', checkIn: '${j['check_in'] ?? ''}',
    checkOut: '${j['check_out'] ?? ''}', total: double.tryParse('${j['total_amount'] ?? 0}') ?? 0,
    notes: '${j['notes'] ?? ''}',
  );

  Booking copyStatus(String value) => Booking(id: id, guests: guests, reference: reference,
    guest: guest, phone: phone, property: property, room: room, status: value,
    checkIn: checkIn, checkOut: checkOut, total: total, notes: notes);
}

class AgentApi {
  String? token;
  AgentApi({this.token});
  static const demoBookings = <Booking>[
    Booking(id: 101, guests: 2, reference: 'SE8K4P2M', guest: 'Aarav Deshmukh', phone: '+91 98765 43210', property: 'The Fern Cliff Villa', room: 'Sea View Suite', status: 'CONFIRMED', checkIn: '2026-11-28', checkOut: '2026-11-30', total: 18400, notes: 'Late arrival around 8 PM.'),
    Booking(id: 102, guests: 3, reference: 'SE7R9N3Q', guest: 'Mira Kulkarni', phone: '+91 98220 12345', property: 'Serein Valley Retreat', room: 'Premium Valley Cottage', status: 'ENQUIRY', checkIn: '2026-11-29', checkOut: '2026-12-01', total: 22600, notes: 'Guest requested a valley-facing room.'),
    Booking(id: 103, guests: 2, reference: 'SE5T6W8A', guest: 'Kabir Shah', phone: '+91 98900 55522', property: 'Coastal Nest', room: 'Deluxe Ocean Room', status: 'CHECKED_IN', checkIn: '2026-11-25', checkOut: '2026-11-27', total: 12600),
    Booking(id: 104, guests: 4, reference: 'SE2M4B7C', guest: 'Ananya Patil', phone: '+91 97654 32109', property: 'The Fern Cliff Villa', room: 'Garden Villa', status: 'COMPLETED', checkIn: '2026-11-20', checkOut: '2026-11-22', total: 31200),
    Booking(id: 105, guests: 2, reference: 'SE9D3L5X', guest: 'Rohan Mehta', phone: '+91 98111 22334', property: 'Serein Valley Retreat', room: 'Hill View Room', status: 'CANCELLED', checkIn: '2026-11-18', checkOut: '2026-11-20', total: 9800),
  ];

  Future<void> login(String username, String password) async {
    if (demoMode) return;
    final r = await http.post(Uri.parse('$apiBaseUrl/api/agent/token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password})).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception(_message(r));
    token = '${(jsonDecode(r.body) as Map<String, dynamic>)['access']}';
  }

  Map<String, String> get headers => {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};

  Future<List<Booking>> getBookings({String status = 'ALL', String q = ''}) async {
    if (demoMode) {
      var rows = List<Booking>.from(demoBookings);
      if (status != 'ALL') rows = rows.where((b) => b.status == status).toList();
      if (q.trim().isNotEmpty) {
        final s = q.toLowerCase();
        rows = rows.where((b) => b.guest.toLowerCase().contains(s) || b.reference.toLowerCase().contains(s) || b.property.toLowerCase().contains(s)).toList();
      }
      return rows;
    }
    final params = <String, String>{if (status != 'ALL') 'status': status, if (q.trim().isNotEmpty) 'q': q.trim()};
    final uri = Uri.parse('$apiBaseUrl/api/agent/bookings/').replace(queryParameters: params.isEmpty ? null : params);
    final r = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception(_message(r));
    final data = jsonDecode(r.body);
    final list = data is List ? data : (data['results'] as List? ?? []);
    return list.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Booking> setStatus(Booking b, String status) async {
    if (demoMode) return b.copyStatus(status);
    final r = await http.patch(Uri.parse('$apiBaseUrl/api/agent/bookings/${b.id}/status/'),
      headers: headers, body: jsonEncode({'status': status})).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw Exception(_message(r));
    return Booking.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  static String _message(http.Response r) {
    try { final d = jsonDecode(r.body); return '${d['detail'] ?? d}'; }
    catch (_) { return 'Request failed (${r.statusCode}). Check the API URL and server.'; }
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}
class _SessionGateState extends State<SessionGate> {
  bool loading = true;
  String? token;
  @override
  void initState() { super.initState(); _init(); }
  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('agent_token');
    if (mounted) setState(() => loading = false);
  }
  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return token != null && !demoMode ? AgentHome(api: AgentApi(token: token)) : const LoginScreen();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController(), password = TextEditingController();
  bool busy = false, obscure = true;
  String? error;
  Future<void> submit() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) { setState(() => error = 'Enter username and password.'); return; }
    setState(() { busy = true; error = null; });
    try {
      final api = AgentApi();
      await api.login(username.text.trim(), password.text);
      if (!demoMode) {
        final p = await SharedPreferences.getInstance();
        await p.setString('agent_token', api.token!);
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AgentHome(api: api)));
    } catch (e) { setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  void dispose() { username.dispose(); password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(25), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 58, height: 58, decoration: BoxDecoration(color: const Color(0xFF183A35), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.landscape_rounded, color: Color(0xFFE4C98A), size: 30)),
      const SizedBox(height: 25),
      const Text('SEREIN ESCAPES', style: TextStyle(letterSpacing: 3, fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF9A8050))),
      const SizedBox(height: 8),
      const Text('Agent workspace', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w800, color: Color(0xFF183A35))),
      const SizedBox(height: 8),
      Text(demoMode ? 'Explore the booking workspace in demo mode.' : 'Sign in to manage your guest bookings.', style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
      const SizedBox(height: 30),
      TextField(controller: username, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
      const SizedBox(height: 14),
      TextField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => obscure = !obscure)))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 22),
      SizedBox(width: double.infinity, height: 54, child: FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF183A35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)))),
      if (demoMode) ...[
        const SizedBox(height: 17),
        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFEAE7DC), borderRadius: BorderRadius.circular(14)),
          child: const Text('DEMO ACCESS\nEnter any non-empty username and password to preview the app.', style: TextStyle(height: 1.6, fontSize: 12, color: Color(0xFF4D554F)))),
      ],
      const SizedBox(height: 35),
      Center(child: Text('PREMIUM STAYS · THOUGHTFUL HOSPITALITY', style: TextStyle(fontSize: 9, letterSpacing: 1.3, color: Colors.grey.shade600))),
    ])),
  ))));
}

class AgentHome extends StatefulWidget {
  final AgentApi api;
  const AgentHome({super.key, required this.api});
  @override
  State<AgentHome> createState() => _AgentHomeState();
}
class _AgentHomeState extends State<AgentHome> {
  int tab = 0;
  String filter = 'ALL', query = '';
  final search = TextEditingController();
  bool loading = true;
  String? error;
  List<Booking> rows = [];
  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try { rows = await widget.api.getBookings(status: filter, q: query); }
    catch (e) { error = e.toString().replaceFirst('Exception: ', ''); }
    if (mounted) setState(() => loading = false);
  }
  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('agent_token');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SEREIN ESCAPES', style: TextStyle(fontSize: 11, letterSpacing: 2.2, fontWeight: FontWeight.w800, color: Color(0xFF9A8050))),
      Text('Agent workspace', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
    ]), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)), IconButton(onPressed: logout, icon: const Icon(Icons.logout_rounded)), const SizedBox(width: 6)]),
    body: tab == 0 ? dashboard() : bookingPage(),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
      NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Overview'),
      NavigationDestination(icon: Icon(Icons.book_online_outlined), selectedIcon: Icon(Icons.book_online), label: 'Bookings'),
    ]),
  );

  Widget dashboard() {
    final enquiries = rows.where((b) => b.status == 'ENQUIRY').length;
    final confirmed = rows.where((b) => b.status == 'CONFIRMED').length;
    final active = rows.where((b) => ['ENQUIRY','CONFIRMED','CHECKED_IN'].contains(b.status)).length;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final arrivals = rows.where((b) => b.checkIn == today).length;
    return RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFF183A35), borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Text('GOOD HOSPITALITY STARTS HERE', style: TextStyle(color: Color(0xFFE4C98A), letterSpacing: 1.5, fontSize: 9, fontWeight: FontWeight.w800)),
          SizedBox(height: 12), Text('Every stay,\\nbeautifully managed.', style: TextStyle(color: Colors.white, fontSize: 25, height: 1.15, fontWeight: FontWeight.w800)),
        ])),
      const SizedBox(height: 12),
      Text('$active active bookings in your workspace', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
      const SizedBox(height: 20),
      const Text('Today at a glance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF183A35))),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: metric('New enquiries', '$enquiries', Icons.mark_email_unread_outlined, const Color(0xFFECE5D3))), const SizedBox(width: 10), Expanded(child: metric('Confirmed', '$confirmed', Icons.verified_outlined, const Color(0xFFDDEAE2)))]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: metric('Arrivals today', '$arrivals', Icons.login_rounded, const Color(0xFFE7E5F0))), const SizedBox(width: 10), Expanded(child: metric('Total records', '${rows.length}', Icons.calendar_month_outlined, const Color(0xFFE9E6E0)))]),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Recent bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF183A35))), TextButton(onPressed: () => setState(() => tab = 1), child: const Text('View all'))]),
      if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
      else if (error != null) errorBox()
      else ...rows.take(3).map((b) => BookingTile(booking: b, onTap: () => openBooking(b))),
    ]));
  }

  Widget metric(String label, String value, IconData icon, Color tint) => Container(
    padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black.withOpacity(.04))),
    child: Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF183A35), size: 19)),
      const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF183A35))),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
      ])),
    ]),
  );

  Widget bookingPage() => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 10), child: TextField(controller: search, onChanged: (v) { query = v; load(); }, decoration: const InputDecoration(hintText: 'Search guest, property or reference', prefixIcon: Icon(Icons.search_rounded)))),
    SizedBox(height: 45, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
      for (final f in const ['ALL','ENQUIRY','CONFIRMED','CHECKED_IN','COMPLETED','CANCELLED'])
        Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(statusLabel(f)), selected: filter == f, onSelected: (_) { setState(() => filter = f); load(); })),
    ])),
    Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : error != null ? errorBox() : rows.isEmpty ? const Center(child: Text('No bookings match this filter.')) : RefreshIndicator(onRefresh: load, child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), itemCount: rows.length, itemBuilder: (_, i) => BookingTile(booking: rows[i], onTap: () => openBooking(rows[i]))))),
  ]);

  Widget errorBox() => Container(padding: const EdgeInsets.all(16), margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(15)), child: Text(error ?? 'Something went wrong', style: TextStyle(color: Colors.red.shade800)));

  Future<void> openBooking(Booking b) async {
    final updated = await Navigator.push<Booking>(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(api: widget.api, booking: b)));
    if (updated != null) load();
  }
}

class BookingTile extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;
  const BookingTile({super.key, required this.booking, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0, margin: const EdgeInsets.only(bottom: 10), color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.black.withOpacity(.04))),
    child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(booking.reference, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Color(0xFF9A8050)))), StatusPill(status: booking.status)]),
      const SizedBox(height: 9),
      Text(booking.guest, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF183A35))),
      const SizedBox(height: 4),
      Text(booking.property, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF9A8050)), const SizedBox(width: 6),
        Expanded(child: Text('${prettyDate(booking.checkIn)}  –  ${prettyDate(booking.checkOut)}', style: const TextStyle(fontSize: 11))),
        Text('₹${NumberFormat('#,##,##0').format(booking.total)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF183A35))),
      ]),
    ]))),
  );
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final c = switch (status) {
      'CONFIRMED' => const Color(0xFF26704E),
      'CHECKED_IN' => const Color(0xFF376B9A),
      'COMPLETED' => const Color(0xFF686868),
      'CANCELLED' => const Color(0xFFB44B4B),
      _ => const Color(0xFF9A8050),
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: c.withOpacity(.10), borderRadius: BorderRadius.circular(20)), child: Text(statusLabel(status), style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .4)));
  }
}

class BookingDetailScreen extends StatefulWidget {
  final AgentApi api;
  final Booking booking;
  const BookingDetailScreen({super.key, required this.api, required this.booking});
  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}
class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Booking booking;
  bool busy = false;
  String? error;
  @override
  void initState() { super.initState(); booking = widget.booking; }
  Future<void> change(String next) async {
    setState(() { busy = true; error = null; });
    try {
      booking = await widget.api.setStatus(booking, next);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking updated to ${statusLabel(next)}')));
    } catch (e) { setState(() => error = e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final actions = switch (booking.status) {
      'ENQUIRY' => [('Confirm booking', 'CONFIRMED'), ('Cancel booking', 'CANCELLED')],
      'CONFIRMED' => [('Mark checked-in', 'CHECKED_IN'), ('Cancel booking', 'CANCELLED')],
      'CHECKED_IN' => [('Complete stay', 'COMPLETED')],
      _ => <(String, String)>[],
    };
    return Scaffold(appBar: AppBar(title: const Text('Booking details', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xFF183A35), borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('BOOKING REFERENCE', style: TextStyle(color: Color(0xFFE4C98A), letterSpacing: 1.5, fontSize: 9, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8), Text(booking.reference, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 1.3)),
          const SizedBox(height: 14), StatusPill(status: booking.status),
        ])),
        const SizedBox(height: 20), const Text('Guest information', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF183A35))),
        const SizedBox(height: 10), detailCard([
          detail(Icons.person_outline, 'Guest', booking.guest), detail(Icons.phone_outlined, 'Phone', booking.phone), detail(Icons.people_outline, 'Guests', '${booking.guests}'),
        ]),
        const SizedBox(height: 18), const Text('Stay details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF183A35))),
        const SizedBox(height: 10), detailCard([
          detail(Icons.holiday_village_outlined, 'Property', booking.property), detail(Icons.bed_outlined, 'Room', booking.room),
          detail(Icons.login_outlined, 'Check-in', prettyDate(booking.checkIn)), detail(Icons.logout_outlined, 'Check-out', prettyDate(booking.checkOut)),
          detail(Icons.currency_rupee, 'Booking value', '₹${NumberFormat('#,##,##0').format(booking.total)}'),
        ]),
        if (booking.notes.isNotEmpty) ...[
          const SizedBox(height: 18), const Text('Guest notes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF183A35))),
          const SizedBox(height: 10), detailCard([detail(Icons.notes_rounded, 'Special request', booking.notes)]),
        ],
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 22), const Text('Booking actions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF183A35))),
          const SizedBox(height: 10),
          for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: 9), child: SizedBox(height: 52, child: FilledButton(
            onPressed: busy ? null : () async {
              final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                title: Text(a.$1), content: Text('Are you sure you want to ${a.$1.toLowerCase()}?'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm'))],
              ));
              if (ok == true) await change(a.$2);
            },
            style: FilledButton.styleFrom(backgroundColor: a.$2 == 'CANCELLED' ? const Color(0xFF9B4747) : const Color(0xFF183A35), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: busy ? const CircularProgressIndicator(color: Colors.white) : Text(a.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
          ))),
        ],
        const SizedBox(height: 20), OutlinedButton.icon(onPressed: () => Navigator.pop(context, booking), icon: const Icon(Icons.arrow_back), label: const Text('Back to bookings')),
      ]),
    );
  }
  Widget detailCard(List<Widget> children) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black.withOpacity(.04))), child: Column(children: children));
  Widget detail(IconData icon, String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 18, color: const Color(0xFF9A8050)), const SizedBox(width: 10),
    SizedBox(width: 92, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
    Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF183A35)))),
  ]));
}

String statusLabel(String s) => switch (s) {
  'ALL' => 'All', 'ENQUIRY' => 'Enquiry', 'CONFIRMED' => 'Confirmed',
  'CHECKED_IN' => 'Checked in', 'COMPLETED' => 'Completed', 'CANCELLED' => 'Cancelled', _ => s,
};
String prettyDate(String s) {
  if (s.isEmpty) return '—';
  try { return DateFormat('dd MMM yyyy').format(DateTime.parse(s)); } catch (_) { return s; }
}
