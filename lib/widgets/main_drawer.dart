import 'package:flutter/material.dart';

class MainDrawer extends StatelessWidget {
  final int pageIndex;
  final Function(int) setPageIndex;

  const MainDrawer({
    Key? key,
    required this.pageIndex,
    required this.setPageIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // const DrawerHeader(
          //   decoration: BoxDecoration(color: Colors.blue),
          //   child: Text('Drawer Header'),
          // ),
          _buildDrawerItem(
            context: context,
            icon: Icons.bug_report,
            text: 'Issues',
            isSelected: pageIndex == 0,
            onTap: () => setPageIndex(0),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.timer,
            text: 'Timesheet',
            isSelected: pageIndex == 1,
            onTap: () => setPageIndex(1),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.settings,
            text: 'Settings',
            isSelected: pageIndex == 2,
            onTap: () => setPageIndex(2),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      selected: isSelected,
      onTap: () {
        onTap();
        Navigator.pop(context); // Close the drawer
      },
    );
  }
}
