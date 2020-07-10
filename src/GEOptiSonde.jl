module GEOptiSonde

using LibSerialPort
using Reactive
using DataStructures
using Dates

const Td = Signal((now(),0.0))
const buffer = Signal(CircularBuffer{String}(4))
const currentLine = Signal("")


""" 
    configure_port(port_name)

    Configures the serial port for communication.
"""
function configure_port(port_name)
    port = sp_get_port_by_name(port_name)
    sp_open(port, SP_MODE_READ_WRITE)
    config = sp_get_config(port)
    sp_set_config_baudrate(config, 38400)
    sp_set_config_parity(config, SP_PARITY_NONE)
    sp_set_config_bits(config, 8)
    sp_set_config_stopbits(config, 1)
    sp_set_config_rts(config, SP_RTS_OFF)
    sp_set_config_cts(config, SP_CTS_IGNORE)
    sp_set_config_dtr(config, SP_DTR_OFF)
    sp_set_config_dsr(config, SP_DSR_IGNORE)
    sp_set_config(port, config)
    return port
end

function read(port)
    sp_drain(port)
    sp_flush(port, SP_BUF_OUTPUT)
    nbytes_read, bytes = sp_nonblocking_read(port, 2000)

    x = String(bytes)

    a = split(currentLine.value*x,"\0")
    b = try 
        (a[length.(a) .> 0])[1]
    catch
        return nothing
    end
    c = split(b, "\n")
    d = (c[length.(c) .> 0])
    push!(currentLine, "")
    map(d) do x
        if (x[end] == '\r') 
            out = convert(String, x[1:end-1])
            push!(buffer.value,out)
        else
            push!(currentLine, x)
        end
    end

    mTd = map(buffer.value) do x
        a = split(x, "=")
        if a[1] == "Tdew C"
            Tdew = try
                parse(Float64,a[2])
            catch
                nothing
            end
        end
    end
    ret = try
        mTd[.~isnothing.(mTd)][end]
    catch
        nothing
    end

    if ~isnothing(ret) 
        push!(Td, (now(),ret))
    end

    return nothing
end

end
