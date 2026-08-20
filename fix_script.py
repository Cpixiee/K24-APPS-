path = '/Users/mac/project/apps_k24/lib/pages/detail_pesanan_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
skip = False
for i, l in enumerate(lines):
    if 'content: Text(' in l and i+1 < len(lines) and 'Seluruh invoice' in lines[i+1]:
        continue
    if 'Seluruh invoice pada pengantaran' in l:
        new_lines.append(r"        content: Text('Seluruh invoice pada pengantaran ' + (_currentOrder.dispatchId.isNotEmpty ? _currentOrder.dispatchId : _currentOrder.orderNumber) + ' telah diverifikasi.

Silakan kembali ke K-24 Hub untuk Pengembalian POD.', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.4))," + "
")
        skip = True
        continue
    if skip:
        if 'actions: [' in l:
            skip = False
            new_lines.append(l)
        continue
    new_lines.append(l)

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('FIXED SUCCESSFULLY')
