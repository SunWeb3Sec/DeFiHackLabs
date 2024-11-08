# Debug Giao Dịch OnChain: 1. Công cụ

Tác giả: [Sun](https://twitter.com/1nf0s3cpt)

Cộng đồng [Discord](https://discord.gg/3y3d9DMQ)

Bài viết này được đăng trên XREX và [WTF Academy](https://github.com/AmazingAng/WTF-Solidity#%E9%93%BE%E4%B8%8A%E5%A8%81%E8%83%81%E5%88%86%E6%9E%90)

Khi tôi bắt đầu học phân tích giao dịch on-chain, không có nhiều tài liệu học tập online,. Mặc dù chậm, nhưng tôi đã có thể tập hợp đủ thông tin để thực hiện các thử nghiệm và phân tích. 


Từ những nghiên cứu của tôi, chúng tôi sẽ tung ra một loạt bài viết về bảo mật Web3 để thu hút nhiều người tham gia và cùng nhau tạo ra một mạng lưới an toàn.

Trong series đầu tiên, chúng tôi sẽ giới thiệu cách thực hiện phân tích on-chain, sau đó chúng tôi sẽ tái tạo các cuộc tấn công on-chain. Kỹ năng này sẽ giúp chúng ta hiểu quá trình tấn công, nguyên nhân gốc rễ của các lỗ hổng, và thậm chí cách các robot thực thi chênh lệch giá.

## Các công tăng cường hiệu suất
Trước khi bước vào phân tích, cho phép tôi giới thiệu một số công cụ thông dụng. Các công cụ đúng có thể giúp bạn thực hiện việc nghiên cứu hiệu quả hơn
### Công cụ debug giao dịch
[Phalcon](https://phalcon.blocksec.com/) | [Tx.viewer](https://tx.eth.samczsun.com/) | [Cruise](https://cruise.supremacy.team/) | [Ethtx](https://ethtx.info/) | [Tenderly](https://dashboard.tenderly.co/explorer)


Các công cụ xem giao dịch (Transaction Viewers) được sử dụng phổ biến nhất, chúng có thể liệt kê ra hàm gọi và dữ liệu đầu vào mỗi hàm trong các giao dịch. Các công cụ xem giao dịch khá tương đồng, khác biệt giữa chúng nằm ở các chain mà chúng hỗ trợ và mỗi công cụ có những chức năng phụ khác nhau. Cá nhân tôi sử dụng Phalcon và Sam's Transaction Viewer. Với những chain mà chúng không hỗ trợ, tôi sẽ dùng Tenderly. Tenderly hỗ trợ hầu hết chain, nhưng không dễ hiểu bằng các công cụ kia, và việc phân tích có thể chậm khi dùng tính năng Debug. Tuy nhiên, đó là một trong những công cụ đầu tiên mà tôi dùng để học cùng với Ethtx.

#### So sánh các chain hỗ trợ (của các Transaction Viewer)

Phalcon： `Ethereum、BSC、Avalanche C-Chain、Polygon、Solana、Arbitrum、Fantom、Optimism、Base、Linea、zkSync Era、Kava、Evmos、Merlin、Manta、Mantle、Holesky testnet、Sepolia testnet`

Sam's Transaction viewer： `Ethereum、Polygon、BSC、Avalanche C-Chain、Fantom、Arbitrum、Optimism`

Cruise： `Ethereum、BSC 、Polygon、Arbitrum、Fantom、Optimism、Avalanche、Celo、Gnosis`

Ethtx： `Ethereum、Goerli testnet`

Tenderly： `Ethereum、Polygon、BSC、Sepolia、Goerli、Gnosis、POA、RSK、Avalanche C-Chain、Arbitrum、Optimism
、Fantom、Moonbeam、Moonriver`

#### Phòng thí nghiệm
Chúng ta sẽ "mổ xẻ" giao dịch trong [cuộc tấn công](https://github.com/SunWeb3Sec/DeFiHackLabs/#20221229---jay---insufficient-validation--reentrancy) (JayPeggers - kiểm tra không dầy đủ + tấn công lặp lại). [TXID](https://phalcon.blocksec.com/tx/eth/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6) 

Đầu tiên, tôi sử dụng công cụ Phalcon được phát triển bởi Blocksec để minh họa. Chúng ta có thể thấy thông tin cơ bản và thay đổi số dư của giao dịch trong hình dưới đây. Từ sự thay đổi số dư, chúng ta có thể nhanh chóng thấy kẻ tấn công đã có được bao nhiêu lợi nhuận. Trong ví dụ này, lợi nhuận của kẻ tấn công là 15.32 ETH.

![210571234-402d96aa-fe5e-4bc4-becc-190bd5a78e68-2](https://user-images.githubusercontent.com/107249780/210686382-cc02cc6a-b8ec-4cb7-ac19-402cd8ff86f6.png)

Hiển thị dòng gọi thực thi (Invocation Flow Visualization) - là một chức năng gọi với thông tin cấp theo dõi (trace-level information) và các log sự kiện (event log). Nó cho chúng ta biết các lần gọi thực thi, mức độ gọi hàm của giao dịch, có sử dụng khoản vay nhanh (flashloan) hay không, các dự án liên quan, hàm nào được gọi và các tham số và dữ liệu thô được đưa vào, vv.

![圖片](https://user-images.githubusercontent.com/52526645/210572053-eafdf62a-7ebe-4caa-a905-045e792add2b.png)

Phalcon 2.0 đã thêm quá trình di chuyển của dòng tiền (funds flow), công cụ Debug + các phân tích source code trực tiếp có thể xem được source code, tham số và các giá trị trả về cùng với các "vết" (trace). Chúng rất tiện lợi cho việc phân tích.

![image](https://user-images.githubusercontent.com/107249780/210821062-d1da8d1a-9615-4f1f-838d-34f27b9c3f41.png)

Bây giờ chúng ta sẽ dùng công cụ Sam's Transaction Viewer cho [TXID](https://tx.eth.samczsun.com/ethereum/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6) vừa rồi. Sam đã tích hợp nhiều công cụ trong đó, như thể hiện trong hình bên dưới, bạn có thể thấy được sự thay đổi trong Storage và Gas tiêu thụ bởi mỗi thực thi gọi (call).

![210574290-790f6129-aa82-4152-b3e1-d21820524a0a-2](https://user-images.githubusercontent.com/107249780/210686653-f964a682-d2a7-4b49-bafc-c9a2b0fa2c55.png)

Bấm Call ở bên trái để giải mã Dữ Liệu Đầu Vào sơ cấp (raw Input Data).

![圖片](https://user-images.githubusercontent.com/52526645/210575619-89c8e8de-e2f9-4243-9646-0661b9483913.png)

Bây giờ chúng ta sẽ dùng Tenderly để phân tích giao dịch của chúng ta [TXID](https://dashboard.tenderly.co/tx/mainnet/0xd4fafa1261f6e4f9c8543228a67caf9d02811e4ad3058a2714323964a8db61f6), bạn có thể thấy được thông tin cơ bản như các công cụ khác. Nhưng khi sử dụng tính năng Debug, nó không hiển thị như các công cụ đó và cần phải phân tích từng bước một. Tuy nhiên, bạn có thể xem mã và quá trình chuyển đổi dữ liệu đầu vào khi Debugging.

![圖片](https://user-images.githubusercontent.com/52526645/210577802-c455545c-80d7-4f35-974a-dadbe59c626e.png)

Điều này có thể giúp chúng ta xác định tất cả những thứ giao dịch này đã thực hiện. Trước khi viết POC, chúng ta có thể tái hiện tấn công replay không? Có! Cả Tenderly hoặc Phalcon đều hỗ trợ mô phỏng giao dịch, bạn có thể thấy nút Re-Simulate ở góc trên bên phải trong hình trên. Công cụ sẽ tự động điền các giá trị tham số từ giao dịch cho bạn như trong hình dưới đây. Các tham số có thể được thay đổi theo nhu cầu mô phỏng, chẳng hạn như thay đổi số thứ tự block, From, Gas, dữ liệu đầu vào, v.v.

![圖片](https://user-images.githubusercontent.com/52526645/210580340-f2abf864-e540-4881-8482-f28030e5e35b.png)

### Cơ sở dữ liệu chữ ký Ethereum

[4byte](https://www.4byte.directory/) | [sig.eth](https://sig.eth.samczsun.com/) | [etherface](https://www.etherface.io/hash)

Trong Dữ Liệu Đầu Vào sơ cấp (raw Input Data), 4 bytes đầu là chữ ký của function (Function Signatures). Đôi khi nếu Etherscan hay công cụ phân tích khác có thể xác địch được hàm, chúng có thể kiểm tra các hàm thông qua cơ sở dữ liệu chữ ký. 

Ví dụ sau đây giả sử rằng chúng ta không biết hàm  `0xac9650d8` là gì.

![image](https://user-images.githubusercontent.com/107249780/211152650-bfe5ca56-971c-4f38-8407-8ca795fd5b73.png)

Thông qua một truy vấn sig.eth, chúng ta tìm được chữ ký 4 bytes là `multicall(bytes[])` 

![圖片](https://user-images.githubusercontent.com/52526645/210583416-c31bbe07-fa03-4701-880d-0ae485b171f7.png)

### Các công cụ hữu dụng

[Chuyển ABI thành Interface](https://gnidan.github.io/abi-to-sol/) | [Lấy ABI cho contract chưa xác minh](https://abi.w1nt3r.xyz/) | [Bộ giải mã ETH CallData](https://apoorvlathey.com/eth-calldata-decoder/) | [ETHCMD - Guess ABI](https://www.ethcmd.com/)

Chuyển ABI thành Interface: Khi phát triển POC, bạn cần gọi các contracts khác bằng interface. Chúng ta có thể dùng công cụ này để nhanh chúng tạo interface. Vào Etherscan để copy ABI vào công cụ này để lấy interface. [Ví dụ](https://etherscan.io/address/0xb3da8d6da3ede239ccbf576ca0eaa74d86f0e9d3#code).

![圖片](https://user-images.githubusercontent.com/52526645/210587442-e7853d8b-0613-426e-8a27-d70c80e2a42d.png)
![圖片](https://user-images.githubusercontent.com/52526645/210587682-5fb07a01-2b21-41fa-9ed5-e7f45baa0b3e.png)

Bộ giải mã ETH Calldata: Nếu bạn muốn giải mã input data mà không dùng ABI, thì đây là công cụ bạn cần. Với Sam's Transaction Viewer mà tôi giới thiệu hồi nãy cũng hỗ trợ giải mã dữ liệu đầu vào.

![圖片](https://user-images.githubusercontent.com/52526645/210585761-efd8b6f1-b901-485f-ae66-efaf9c84869c.png)

Lấy ABI cho contracts chưa xác minh: Nếu bạn gặp contract chưa được xác minh, bạn có thể dùng công cụ này để tìm ra chữ ký hàm. [Ví dụ](https://abi.w1nt3r.xyz/mainnet/0xaE9C73fd0Fd237c1c6f66FE009d24ce969e98704)

![圖片](https://user-images.githubusercontent.com/52526645/210588945-701b0e22-7390-4539-9d2f-e13479b52824.png)

### Các công cụ biên dịch ngược
[Etherscan-decompile bytecode](https://etherscan.io/address/0xaE9C73fd0Fd237c1c6f66FE009d24ce969e98704#code) | [Dedaub](https://library.dedaub.com/decompile) | [heimdall-rs](https://github.com/Jon-Becker/heimdall-rs)

Etherscan có tính năng biên dịch ngược (decompilation), nhưng độ đọc hiểu của kết quả thường không tốt. Cá nhân tôi thường sử dụng Dedaub, nó có thể tạo ra biên dịch ngược tốt hơn. Tôi khuyên bạn nên dùng Dedaub. Hãy cùng sử dụng một MEV Bot bị tấn công làm ví dụ. Bạn có thể thử thực hiện biên dịch ngược bằng [contract](https://twitter.com/1nf0s3cpt/status/1577594615104172033).

Đầu tiên, copy Bytecodes của contract chưa xác minh vào Dedaub rồi click Decompile.

![截圖 2023-01-05 上午10 33 15](https://user-images.githubusercontent.com/107249780/210688395-927c6126-b6c1-4c6d-a0c7-a3fea3db9cdb.png)

![圖片](https://user-images.githubusercontent.com/52526645/210591478-6fa928f3-455d-42b5-a1ac-6694f97386c2.png)

Nếu bạn muốn học thêm, bạn có xem các Video dưới đây.

## Tài nguyên
[eth txn explorer và vscode extension của samczsun](https://www.youtube.com/watch?v=HXgu239mPBc)

[Lỗ Hổng Trong Defi - Daniel V.F.](https://www.youtube.com/watch?v=9fcOffCg2ig)

[Tenderly.co - Debug giao dịch](https://www.youtube.com/watch?v=90GN9Ut8LhU)

[Đảo ngược EVM: Calldata sơ cấp](https://degatchi.com/articles/reading-raw-evm-calldata)

https://web3sec.xrex.io/

