
@async begin
           server = listen(2001)
           while true
               sock = accept(server)
               @async while isopen(sock)
                   x = readline(sock)
                   println("Host read: $x")
                   write(sock, x)
               end
           end
       end

conn = connect(2001)

@async begin
  while !eof(conn)
    info(read(conn, Char))
  end

  println("Ended reading from connection (eof found)")
end

