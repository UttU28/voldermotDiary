import 'package:flutter/material.dart';

class PagesListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> pages;
  final bool isLoadingPages;
  final String? pagesErrorMessage;
  final VoidCallback onRefresh;
  final Function(String) onPageTap;
  final Function(String) onPageDelete;
  final String Function(int) formatTimestamp;

  const PagesListWidget({
    super.key,
    required this.pages,
    required this.isLoadingPages,
    this.pagesErrorMessage,
    required this.onRefresh,
    required this.onPageTap,
    required this.onPageDelete,
    required this.formatTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pages',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRefresh,
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 8),
        isLoadingPages
            ? const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              )
            : pagesErrorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          pagesErrorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: onRefresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : pages.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No pages yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a new page to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                          final page = pages[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.amber[700],
                                child: const Icon(Icons.description, color: Colors.white),
                              ),
                              title: Text(
                                page['pageName'] ?? 'Untitled Page',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Created: ${formatTimestamp(page['createdAt'] ?? 0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  Text(
                                    'Last active: ${formatTimestamp(page['lastActivity'] ?? 0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _showDeleteDialog(context, page),
                                    tooltip: 'Delete page',
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                                ],
                              ),
                              onTap: () => onPageTap(page['pageId']),
                            ),
                          );
                        },
                      ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> page) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Page'),
          content: Text(
            'Are you sure you want to delete "${page['pageName'] ?? 'Untitled Page'}"?\n\n'
            'This will permanently delete the page and all its drawings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onPageDelete(page['pageId']);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
